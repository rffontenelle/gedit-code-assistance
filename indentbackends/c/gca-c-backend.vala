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

namespace Gca.C
{

class Backend : Object, Gca.IndentBackend
{
	private Gedit.View d_view;

	public Gedit.View view {
		get { return d_view; }
		construct set { d_view = value; }
	}

	string[] get_triggers()
	{
		return { "0{", "0}", "0#", ":" };
	}

	bool move_to_no_space(ref Gtk.TextIter place, bool forward)
	{
		if (place.is_end() && !place.forward_chars(forward ? 1 : -1))
		{
			return false;
		}

		bool moved = true;

		var c = place.get_char();
		while (c.isspace())
		{
			if (!place.forward_chars(forward ? 1 : -1))
			{
				moved = false;
				break;
			}

			c = place.get_char();
		}

		return moved;
	}

	bool find_open_char(ref Gtk.TextIter place, unichar open, unichar close, bool skip_first)
	{
		var copy = place;
		int counter = 0;
		bool moved = false;

		do
		{
			var c = copy.get_char();

			if (c == close || skip_first)
			{
				counter--;
				skip_first = false;
			}

			if (c == open && counter != 0)
			{
				counter++;
			}

			if (counter == 0)
			{
				place = copy;
				moved = true;
				break;
			}
		} while (copy.backward_char());

		return moved;
	}

	unichar get_first_char_in_line(Gtk.TextIter place)
	{
		place.set_line_offset(0);
		unichar c = place.get_char();

		while (c.isspace() && !place.ends_line())
		{
			if (!place.forward_char())
			{
				break;
			}

			c = place.get_char();
		}

		return c;
	}

	uint get_indent(Gedit.Document document, Gtk.TextIter place)
	{
		uint amount = 0;
		var iter = place;

		// if we are in the first line then 0 is fine
		if (iter.get_line() == 0)
		{
			return 0;
		}

		// are we a comment?
		if (document.iter_has_context_class(iter, "comment"))
		{
			// FIXME: leave it as it is for now :)
			return get_line_indents(iter);
		}

		// move to the end of the previous line to get some context from previous lines
		iter.set_line_offset(0);
		if (!iter.backward_char())
		{
			return 0;
		}

		if (!move_to_no_space(ref iter, false))
		{
			return 0;
		}

		if (document.iter_has_context_class(iter, "comment"))
		{
			if (!document.iter_backward_to_context_class_toggle(ref iter, "comment"))
			{
				return 0;
			}
			else
			{
				// align with the start of the comment
				amount = get_line_indents(iter);
			}
		}

		var c = iter.get_char();

		if (c == ';')
		{
			// hello(param1,
			//       param2);
			var copy = iter;
			if (copy.backward_char() && copy.get_char() == ')')
			{
				if (find_open_char(ref copy, '(', ')', false))
				{
					amount = get_line_indents(copy);
				}
				else
				{
					// fallback to try to use the current place
					amount = get_line_indents(iter);
				}
			}
			else
			{
				// hello;
				amount = get_line_indents(iter);
			}
		}
		else if (c == ')')
		{
			var copy = iter;
			if (find_open_char(ref copy, '(', ')', false))
			{
				amount = get_line_indents(copy);

				if (get_first_char_in_line(place) != '{')
				{
					amount += get_indent_width();
				}
			}
		}
		else if (c == '{')
		{
			amount = get_line_indents(iter);
			amount += get_indent_width();
		}
		else if (c == '}')
		{
			amount = get_line_indents(iter);
		}
		else if (c == ',')
		{
			// hello(param1,|
			var copy = iter;
			// FIXME: if we are in an enum we might go out of it and endup with
			// a wrong indentation here
			if (find_open_char(ref copy, '(', ')', true))
			{
				// if we found it we want to align to the position of the first parameter
				amount = get_amount_indents_from_position(copy) + 1;
			}
			else
			{
				amount = get_line_indents(iter);
			}
		}

		if (get_first_char_in_line(place) == '}')
		{
			var copy = place;

			// we know the line starts with } so move the iter to the beginning
			// of the line to search of the opener {
			copy.set_line_offset(0);

			if (find_open_char(ref copy, '{', '}', true))
			{
				amount = get_line_indents(copy);
			}
		}
		else if (get_first_char_in_line(place) == '#')
		{
			amount = 0;
		}

		return amount;
	}
}

}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
	Peas.ObjectModule mod = module as Peas.ObjectModule;

	mod.register_extension_type(typeof(Gca.IndentBackend),
	                            typeof(Gca.C.Backend));
}

/* vi:ex:ts=4 */
