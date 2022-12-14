/*
 * Copyright (C) 2016 Jens Georg <mail@jensge.org>
 *
 * Author: Jens Georg <mail@jensge.org>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

using Soup;
using GUPnP;

internal class Rygel.PhillipsHacks : ClientHacks {
    private const string AGENT = ".*IPI/.*";

    public PhillipsHacks (ServerMessage? message = null) throws ClientHacksError {
        base (AGENT, message);
    }

    public override void apply (MediaObject object) {
        foreach (var resource in object.get_resource_list ()) {
            if (resource.mime_type == "video/x-msvideo") {
                resource.mime_type = "video/avi";
            }
        }
    }
}
