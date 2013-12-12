/*
 * This file is part of gedit-code-assistant.
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
 *
 * gedit-code-assistant is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gedit-code-assistant is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gedit-code-assistant.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

namespace Gca
{

class WindowActivatable : GLib.Object, Gedit.WindowActivatable
{
	public Gedit.Window window { construct; owned get; }

	public void activate()
	{
		window.active_tab_changed.connect(on_active_tab_changed);
	}

	public void deactivate()
	{
		window.active_tab_changed.disconnect(on_active_tab_changed);
	}

	public void update_state()
	{
	}

	private void on_active_tab_changed(Gedit.Window window, Gedit.Tab tab)
	{
		var v = tab.get_view().get_data<View?>("GcaView");

		if (v != null)
		{
			v.reparse();
		}
	}
}

}

/* vi:ex:ts=4 */
