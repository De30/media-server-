/*
 * Copyright (C) 2008-2010 Nokia Corporation.
 * Copyright (C) 2006, 2007, 2008 OpenedHand Ltd.
 * Copyright (C) 2012 Intel Corporation.
 * Copyright (C) 2013 Cable Television Laboratories, Inc.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jorn Baayen <jorn.baayen@gmail.com>
 *         Jens Georg <jensg@openismus.com>
 *         Craig Pratt <craig@ecaspia.com>
 *         Parthiban Balasubramanian <P.Balasubramanian-contractor@cablelabs.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

/**
 * Responsible for handling HTTP GET & HEAD client requests.
 */
public class Rygel.HTTPGet : HTTPRequest {
    private const string TRANSFER_MODE_HEADER = "transferMode.dlna.org";

    public HTTPSeekRequest seek;
    public Thumbnail thumbnail;
    public Subtitle subtitle;

    private int thumbnail_index;
    private int subtitle_index;

    public HTTPGetHandler handler;

    public HTTPGet (HTTPServer   http_server,
                    Soup.Server  server,
                    Soup.Message msg) {
        base (http_server, server, msg);

        this.thumbnail_index = -1;
        this.subtitle_index = -1;
    }

    protected override async void handle () throws Error {
        /* We only entertain 'HEAD' and 'GET' requests */
        if (!(this.msg.method == "HEAD" || this.msg.method == "GET")) {
            throw new HTTPRequestError.BAD_REQUEST
                          (_("Invalid Request (only GET and HEAD supported)"));
        }

        { /* Check for proper content feature request */
            var cf_header = "getcontentFeatures.dlna.org";
            var cf_val = this.msg.request_headers.get_one (cf_header);

            if (cf_val != null && cf_val != "1") {
                throw new HTTPRequestError.BAD_REQUEST (_(cf_header + " must be 1"));
            }
        }

        if (uri.resource_name != null) {
            this.handler = new HTTPMediaResourceHandler (this.object,
                                                         uri.resource_name,
                                                         this.cancellable);
        } else if (uri.thumbnail_index >= 0) {
            this.handler = new HTTPThumbnailHandler (this.object as MediaFileItem,
                                                     uri.thumbnail_index,
                                                     this.cancellable);
        } else if (uri.subtitle_index >= 0) {
            this.handler = new HTTPSubtitleHandler (this.object as MediaFileItem,
                                                    uri.subtitle_index,
                                                    this.cancellable);
        }

        { // Check the transfer mode
            var transfer_mode = this.msg.request_headers.get_one (TRANSFER_MODE_HEADER);

            if (transfer_mode == null) {
                transfer_mode = this.handler.get_default_transfer_mode ();
            }

            if (! this.handler.supports_transfer_mode (transfer_mode)) {
                throw new HTTPRequestError.UNACCEPTABLE ("%s transfer mode not supported for '%s'",
                                                        transfer_mode, uri.to_string ());
            }
        }

        yield this.handle_item_request ();
    }

    protected override async void find_item () throws Error {
        yield base.find_item ();

        // No need to do anything here, will be done in PlaylistHandler
        if (this.object is MediaContainer) {
            return;
        }

        if (unlikely ((this.object is MediaFileItem)
                      && (this.object as MediaFileItem).place_holder)) {
            throw new HTTPRequestError.NOT_FOUND ("Item '%s' is empty",
                                                  this.object.id);
        }

        if (this.hack != null) {
            this.hack.apply (this.object);
        }

        if (this.uri.thumbnail_index >= 0) {
            if (this.object is MusicItem) {
                var music = this.object as MusicItem;
                this.thumbnail = music.album_art;

                return;
            } else if (this.object is VisualItem) {
                var visual = this.object as VisualItem;
                if (this.uri.thumbnail_index < visual.thumbnails.size) {
                    this.thumbnail = visual.thumbnails.get
                                            (this.uri.thumbnail_index);

                    return;
                }
            }

            throw new HTTPRequestError.NOT_FOUND
                                        ("No Thumbnail available for item '%s",
                                         this.object.id);
        }

        if (this.uri.subtitle_index >= 0 && this.object is VideoItem) {
            var video = this.object as VideoItem;

            if (this.uri.subtitle_index < video.subtitles.size) {
                this.subtitle = video.subtitles.get (this.uri.subtitle_index);

                return;
            }

            throw new HTTPRequestError.NOT_FOUND
                                        ("No subtitles available for item '%s",
                                         this.object.id);
        }
    }

    private async void handle_item_request () throws Error {
        var supports_time_seek = HTTPTimeSeekRequest.supported (this);
        var requested_time_seek = HTTPTimeSeekRequest.requested (this);
        var supports_byte_seek = HTTPByteSeekRequest.supported (this);
        var requested_byte_seek = HTTPByteSeekRequest.requested (this);

        if (requested_byte_seek) {
            if (!supports_byte_seek) {
                throw new HTTPRequestError.UNACCEPTABLE ( "Byte seek not supported for "
                                                          + this.uri.to_string () );
            }
        } else if (requested_time_seek) {
            if (!supports_time_seek) {
                throw new HTTPRequestError.UNACCEPTABLE ( "Time seek not supported for "
                                                          + this.uri.to_string () );
            }
        }

        try {
            // Order is intentional here
            if (supports_byte_seek && requested_byte_seek) {
                var byte_seek = new HTTPByteSeekRequest (this);
                debug ("Processing byte range request (bytes %lld to %lld)",
                       byte_seek.start_byte, byte_seek.end_byte);
                this.seek = byte_seek;
            } else if (supports_time_seek && requested_time_seek) {
                // Assert: speed_request has been checked/processed
                var time_seek = new HTTPTimeSeekRequest (this);
                debug ("Processing " + time_seek.to_string ());
                this.seek = time_seek;
            } else {
                this.seek = null;
            }
        } catch (HTTPSeekRequestError error) {
            warning ("Caught HTTPSeekRequestError: " + error.message);
            this.server.unpause_message (this.msg);
            this.end (error.code, error.message); // All seek error codes are Soup.Status codes
            return;
         }

        // Add headers
        this.handler.add_response_headers (this);

        var response = this.handler.render_body (this);

        // Have the response process the seek/speed request
        try {
            var responses = response.preroll ();

            // Incorporate the prerolled responses
            if (responses != null) {
                foreach (var response_elem in responses) {
                    response_elem.add_response_headers (this);
                }
            }
        } catch (HTTPSeekRequestError error) {
            warning ("Caught HTTPSeekRequestError on preroll: " + error.message);
            this.server.unpause_message (this.msg);
            this.end (error.code, error.message); // All seek error codes are Soup.Status codes
            return;
        }

        // Determine the size value
        int64 response_size;
        {
            // Response size might have already been set by one of the response elements
            response_size = this.msg.response_headers.get_content_length ();

            if (response_size > 0) {
                this.msg.response_headers.set_content_length (response_size);
                debug ("Response size set via response element: size "
                       + response_size.to_string());
            } else {
                // If not already set by a response element, try to set it to the resource size
                if ((response_size = this.handler.get_resource_size ()) > 0) {
                    this.msg.response_headers.set_content_length (response_size);
                    debug ("Response size set via response element: size "
                           + response_size.to_string());
                } else {
                    debug ("Response size unknown");
                }
            }
            // size will factor into other logic below...
        }

        // Determine the transfer mode encoding
        {
            Soup.Encoding response_body_encoding;
            // See DLNA 7.5.4.3.2.15 for requirements
            if (response_size > 0) {
                // TODO: Incorporate ChunkEncodingMode.dlna.org request into this block
                response_body_encoding = Soup.Encoding.CONTENT_LENGTH;
                debug ("Response encoding set to CONTENT-LENGTH");
            } else { // Response size is <= 0
                if (this.msg.get_http_version () == Soup.HTTPVersion.@1_0) {
                    // Can't send the length and can't send chunked (in HTTP 1.0)...
                    response_body_encoding = Soup.Encoding.EOF;
                    debug ("Response encoding set to EOF");
                } else {
                    response_body_encoding = Soup.Encoding.CHUNKED;
                    debug ("Response encoding set to CHUNKED");
                }
            }
            this.msg.response_headers.set_encoding (response_body_encoding);
        }

        // Determine the Vary header (if not HTTP 1.0)
        {
            // Per DLNA 7.5.4.3.2.35.4, the Vary header needs to include the timeseek
            // header if it is supported for the resource/uri
            if (supports_time_seek) {
                if (this.msg.get_http_version () != Soup.HTTPVersion.@1_0) {
                    var vary_header = new StringBuilder
                                             (this.msg.response_headers.get_list ("Vary"));
                    if (supports_time_seek) {
                        if (vary_header.len > 0) {
                            vary_header.append (",");
                        }
                        vary_header.append (HTTPTimeSeekRequest.TIMESEEKRANGE_HEADER);
                    }
                    this.msg.response_headers.replace ("Vary", vary_header.str);
                }
            }
        }

        // Determine the status code
        {
            int response_code;
            if (this.msg.response_headers.get_one ("Content-Range") != null) {
                response_code = Soup.Status.PARTIAL_CONTENT;
            } else {
                response_code = Soup.Status.OK;
            }
            this.msg.set_status (response_code);
        }

        if (msg.get_http_version () == Soup.HTTPVersion.@1_0) {
            // Set the response version to HTTP 1.1 (see DLNA 7.5.4.3.2.7.2)
            msg.set_http_version (Soup.HTTPVersion.@1_1);
            msg.response_headers.append ("Connection", "close");
        }

        debug ("Following HTTP headers appended to response:");
        this.msg.response_headers.foreach ((name, value) => {
            debug ("%s : %s", name, value);
        });

        if (this.msg.method == "HEAD") {
            // Only headers requested, no need to send contents
            this.server.unpause_message (this.msg);

            return;
        }

        yield response.run ();

        this.end (Soup.Status.NONE);
    }
}
