/*
 * This file is part of gedit-code-assistant.
 *
 * Copyright (C) 2014 - Ignacio Casal Quinteiro
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

namespace Gca
{

public interface IndentBackend : Object
{
	public abstract Gedit.View view { get; construct set; }

	/* These are the chars that trigger an extra indentation, i.e { */
	public abstract string[] get_triggers();
	/* It returns the indentation level */
	public abstract uint get_indent(Gedit.Document document, Gtk.TextIter place);

	public uint get_indent_width()
	{
		return view.indent_width < 0 ? view.tab_width : view.indent_width;
	}

	public uint get_line_indents(Gtk.TextIter place)
	{
		var start = place;
		start.set_line_offset(0);

		var c = start.get_char();

		while (c.isspace() && c != '\n' && c != '\r')
		{
			if (!start.forward_char())
			{
				break;
			}

			c = start.get_char();
		}

		return get_amount_indents_from_position(start);
	}

	public uint get_amount_indents_from_position(Gtk.TextIter place)
	{
		var indent_width = get_indent_width();

		var start = place;
		start.set_line_offset(0);

		int rest = 0;
		uint amount = 0;
		var c = start.get_char();
		while (start.compare(place) < 0)
		{
			if (c == '\t')
			{
				if (rest != 0)
				{
					rest = 0;
				}
				amount += indent_width;
			}
			else
			{
				rest++;
			}

			if (rest == indent_width)
			{
				amount += indent_width;
				rest = 0;
			}

			if (!start.forward_char())
			{
				break;
			}

			c = start.get_char();
		}

		return amount + rest;
	}
}

}

/* vi:ex:ts=4 */
