/*
 * Copyright (C) 2010-2014 Jens Georg <mail@jensge.org>.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Jens Georg <mail@jensge.org>
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

internal errordomain MediaArtStoreError {
    NO_DIR,
    NO_MEDIA_ART
}

/**
 * This maps RygelMusicItem objects to their cached cover art,
 * implementing the GNOME
 * [[https://live.gnome.org/MediaArtStorageSpec|MediaArt storage specification]].
 */
public class Rygel.MediaArtStore : GLib.Object {
    private static MediaArtStore media_art_store;
    private static bool first_time = true;
    private const string[] types = { "track", "album", "artist", "podcast", "radio", "video" };

    private MediaArt.Process? media_art_process;

    /**
     * Get the MediaArtStore singleton instance.
     * @return null if the there was an issue using libmediaart
     */
    public static MediaArtStore? get_default () {
        if (first_time) {
            try {
                MediaArt.plugin_init (128);
                media_art_store = new MediaArtStore ();
            } catch (MediaArtStoreError error) {
                warning ("No media art available: %s", error.message);
            }
        }

        first_time = false;

        return media_art_store;
    }

    public Thumbnail? lookup_media_art (MediaItem item) throws Error {
        File file = null;

        foreach (var type in MediaArtStore.types) {
            MediaArt.get_file (item.artist,
                               (type == "album" && item is MusicItem) ?
                                   (item as MusicItem).album : item.title,
                               type,
                               out file);
            message ("Trying to find file for type %s and %s -> %s",
                     item.title, type, file != null ? file.get_uri () : "None");

            if (file != null && file.query_exists (null)) {
                break;
            } else {
                file = null;
            }
        }

        if (file == null) {
            return null;
        }

        var info = file.query_info (FileAttribute.ACCESS_CAN_READ + "," +
                                    FileAttribute.STANDARD_SIZE,
                                    FileQueryInfoFlags.NONE,
                                    null);
        if (!info.get_attribute_boolean (FileAttribute.ACCESS_CAN_READ)) {
            return null;
        }

        var thumb = new Thumbnail ();
        thumb.uri = file.get_uri ();
        thumb.size = (int64) info.get_size ();

        return thumb;
    }

    /**
     * Add binary data as media art for a media item.
     *
     * @item A MediaItem containing the meta-data for @file
     * @file File on the disk
     * @data the binary data of the art
     * @mime the content-type of the binary data
     */
    public void add (MediaItem item, File file, uint8[] data, string mime) {
        if (this.media_art_process == null) {
            return;
        }

        MediaArt.Type type;
        string title;
        if (!this.get_type_and_title (item, out type, out title)) {
            return;
        }

        try {
            // Setting artist to " " is a work-around for bgo#739942
            this.media_art_process.buffer (type,
                                           MediaArt.ProcessFlags.NONE,
                                           file,
                                           data,
                                           mime,
                                           item.artist ?? " ",
                                           title);
        } catch (Error error) {
            warning (_("Failed to add album art for %s: %s"),
                     file.get_uri (),
                     error.message);
        }
    }

    /**
     * Try to lookup external media art for a media item.
     *
     * @item A MediaItem containing the meta-data for @file
     * @file File on the disk
     */
    public void add_external (MediaItem item, File file) {
        if (this.media_art_process == null) {
            return;
        }

        MediaArt.Type type;
        string title;
        if (!this.get_type_and_title (item, out type, out title)) {
            return;
        }

        try {
            this.media_art_process.file (type,
                                         MediaArt.ProcessFlags.NONE,
                                         file,
                                         item.artist,
                                         title);
        } catch (Error error) {
            warning (_("Failed to find media art for %s: %s"),
                     file.get_uri (),
                     error.message);
        }
    }

    private bool get_type_and_title (MediaItem item,
                                     out MediaArt.Type type,
                                     out string title) {
        type = MediaArt.Type.NONE;
        title = null;

        if (item is MusicItem) {
            type = MediaArt.Type.ALBUM;
            title = (item as MusicItem).album;
        } else if (item is VideoItem) {
            type = MediaArt.Type.VIDEO;
            title = item.title;
        } else {
            return false;
        }

        return true;
    }

    private MediaArtStore () throws MediaArtStoreError {
        try {
            this.media_art_process = new MediaArt.Process ();
        } catch (Error error) {
            this.media_art_process = null;
            throw new MediaArtStoreError.NO_MEDIA_ART ("%s", error.message);
        }
    }
}
