/*
 * Copyright (C) 2008 Zeeshan Ali (Khattak) <zeeshanak@gnome.org>.
 * Copyright (C) 2008 Nokia Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
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

using Gst;

/**
 * Represents Test audio item.
 */
public class Rygel.Test.AudioItem : Rygel.AudioItem {
    private const string TEST_MIMETYPE = "audio/x-wav";
    private const string PIPELINE = "audiotestsrc is-live=1 ! wavenc";

    public AudioItem (string id, MediaContainer parent, string title) {
        base (id, parent, title);

        this.mime_type = TEST_MIMETYPE;
    }

    public override Element? create_stream_source (string? host_ip) {
        try {
            return parse_bin_from_description (PIPELINE, true);
        } catch (Error err) {
            warning ("Required plugin missing (%s)", err.message);

            return null;
        }
    }
}

