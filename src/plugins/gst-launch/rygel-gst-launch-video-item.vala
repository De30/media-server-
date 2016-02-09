/*
 * Copyright (C) 2009 Thijs Vermeir <thijsvermeir@gmail.com>
 * Copyright (C) 2010 Nokia Corporation.
 * Copyright (C) 2012 Intel Corporation.
 *
 * Author: Thijs Vermeir <thijsvermeir@gmail.com>
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jens Georg <jensg@openismus.com>
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
 * Video item that serves data from a gst-launch commandline.
 */
public class Rygel.GstLaunch.VideoItem : Rygel.VideoItem {

    public VideoItem (string         id,
                      MediaContainer parent,
                      string         title,
                      string         mime_type,
                      string         launch_line) {
        base (id, parent, title);

        this.mime_type = mime_type;
        this.add_uri ("gst-launch://" + Soup.URI.encode (launch_line, ".!"));

        // Call the MediaEngine to determine which item representations it can support
        var media_engine = MediaEngine.get_default ( );
        media_engine.get_resources_for_item.begin ( this,
                                                    (obj, res) => {
            var added_resources = media_engine
                                  .get_resources_for_item.end (res);
            debug ("Adding %d resources to item source %s",
                   added_resources.size, this.get_primary_uri ());
            foreach (var resrc in added_resources) {
               debug ("Media-export item media resource %s",
                      resrc.get_name ());
            }
            this.get_resource_list ().add_all (added_resources);
          });
    }
}
