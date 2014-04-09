/*
 * This file is part of gedit-code-assistant.
 *
 * Copyright (C) 2011 - Jesse van den Kieboom
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
using Gee;

namespace Gca
{

/**
 * Wrapper around Gedit.View.
 *
 * View is a wrapper around Gedit.View. It keeps track of changes to the document
 * of the gedit view and of the language of the document and registers itself
 * with the appropriate assistance backend.
 */
class View : Object
{
	private unowned Gedit.View d_view;
	private Document d_document;
	private Backend d_backend;
	private IndentBackend d_indent_backend;
	private ScrollbarMarker? d_scrollbar_marker;
	private uint d_timeout;

	private RemoteService[] d_services;

	public signal void changed();
	public signal void path_changed(string? prevpath);

	public View(Gedit.View view)
	{
		d_view = view;

		d_view.notify["buffer"].connect(on_notify_buffer);
		d_view.event_after.connect_after(on_event_after);

		connect_document(d_view.buffer as Gedit.Document);

		ScrolledWindow? sw = d_view.parent as ScrolledWindow;

		if (sw != null)
		{
			d_scrollbar_marker = new ScrollbarMarker(sw.get_vscrollbar() as Scrollbar);
		}

		d_services = new RemoteService[] {
			new DiagnosticService()
		};
	}

	public unowned Gedit.View view
	{
		get { return d_view; }
	}

	public Document document
	{
		get { return d_document; }
	}

	public ScrollbarMarker? scrollbar_marker
	{
		get { return d_scrollbar_marker; }
	}

	public void deactivate()
	{
		d_view.notify["buffer"].disconnect(on_notify_buffer);
		d_view.event_after.disconnect(on_event_after);

		disconnect_document();

		d_view = null;
	}

	public void update(RemoteDocument doc)
	{
		foreach (var service in d_services)
		{
			if (d_backend.supports(service.services()))
			{
				service.update(this, doc);
			}
		}
	}

	private void disconnect_document()
	{
		if (d_document == null)
		{
			return;
		}

		var buf = d_document.document;

		buf.notify["language"].disconnect(on_notify_language);
		d_document.changed.disconnect(on_document_changed);
		d_document.path_changed.disconnect(on_document_path_changed);

		unregister_backends();

		d_document = null;
	}

	private void connect_document(Gedit.Document? document)
	{
		disconnect_document();

		if (document == null)
		{
			return;
		}

		d_document = new Document(document);

		var buf = d_document.document;

		buf.notify["language"].connect(on_notify_language);

		d_document.changed.connect(on_document_changed);
		d_document.path_changed.connect(on_document_path_changed);

		update_backends();
	}

	private void on_document_path_changed(string? prevpath)
	{
		path_changed(prevpath);
	}

	public void reparse_now()
	{
		if (d_timeout != 0)
		{
			Source.remove(d_timeout);
			d_timeout = 0;
		}

		changed();
	}

	public void reparse()
	{
		if (d_timeout != 0)
		{
			Source.remove(d_timeout);
		}

		d_timeout = Timeout.add(200, () => {
			d_timeout = 0;
			changed();
			return false;
		});
	}

	private void on_document_changed()
	{
		d_scrollbar_marker.max_line = d_document.document.get_line_count();
		reparse();
	}

	private void update_backends()
	{
		unregister_backends();

		/* Update the backend according to the current language on the buffer */
		if (d_document != null && d_document.document.language != null)
		{
			var manager = BackendManager.instance;

			manager.backend.begin(d_document.document.language.id, (obj, res) => {
				var backend = manager.backend.end(res);
				register_backend(backend);
			});

			BackendManager.IndentBackendInfo? info = manager.indent_backend_info(d_document.document.language.id);
			if (info != null)
			{
				d_indent_backend = (Gca.IndentBackend)Peas.Engine.get_default().create_extension(info.info, typeof(IndentBackend), "view", d_view);
			}
		}
	}

	private void unregister_backends()
	{
		if (d_backend != null)
		{
			foreach (var service in d_services)
			{
				service.destroy();
			}

			d_backend.unregister(this);
			d_backend = null;
		}

		d_indent_backend = null;
	}

	private void register_backend(Backend? backend)
	{
		d_backend = backend;

		if (backend == null)
		{
			return;
		}

		backend.register(this);
		on_document_changed();
	}

	private void on_notify_buffer()
	{
		disconnect_document();
		connect_document(d_view.buffer as Gedit.Document);
	}

	private void on_notify_language()
	{
		update_backends();
	}

	private unichar get_introduced_char(Gtk.TextBuffer buf, ref Gtk.TextIter cur)
	{
		unichar c = 0;

		var start = cur;

		if (start.backward_char())
		{
			c = start.get_char();
		}

		cur = start;

		return c;
	}

	private bool is_whitespaces(Gtk.TextBuffer buf, Gtk.TextIter cur)
	{
		// Check the first char is not space
		if (cur.get_line_offset() == 0)
		{
			return true;
		}

		bool check = true;
		var start = cur;

		start.set_line_offset(0);
		var c = start.get_char();

		while (start.compare(cur) < 0)
		{
			if (!c.isspace())
			{
				check = false;
				break;
			}
		
			if (!start.forward_char())
			{
				check = false;
				break;
			}

			c = start.get_char();
		}
	
		return check;
	}

	private string get_indent_string_from_indent_level(uint level)
	{
		string indent = "";

		if (d_view.insert_spaces_instead_of_tabs)
		{
			indent = string.nfill(level, ' ');
		}
		else
		{
			var indent_width = d_indent_backend.get_indent_width();
			uint tabs = level / indent_width;
			uint spaces = level % indent_width;

			indent = string.nfill(tabs, '\t').concat(string.nfill(spaces, ' '));
		}

		return indent;
	}

	private void on_event_after(Gtk.Widget widget, Gdk.Event event)
	{
		if (d_document == null ||
		    d_indent_backend == null ||
		    event.type != Gdk.EventType.KEY_PRESS ||
		    (event.key.state & Gdk.ModifierType.SHIFT_MASK) != 0)
		{
			return;
		}

		var buf = d_document.document;
		var insert = buf.get_insert();

		Gtk.TextIter cur;
		buf.get_iter_at_mark(out cur, insert);

		bool indent = false;

		if (event.key.keyval == Gdk.Key.Return || event.key.keyval == Gdk.Key.KP_Enter)
		{
			indent = true;
		}
		else
		{
			/* NOTE: for the future we could make the triggers real regexes
			 * although this way worked for vim so it may as well work for us
			 */
			var copy = cur;
			var introduced_char = get_introduced_char(buf, ref copy);

			foreach (var trigger in d_indent_backend.get_triggers())
			{
				// get the last char to validate with the key pressed
				var c = trigger.get_char(trigger.length - 1);
				if (c != introduced_char || event.key.keyval != Gdk.unicode_to_keyval(c))
				{
					continue;
				}

				if (trigger.get_char(0) == '0' && !is_whitespaces(buf, copy))
				{
					break;
				}

				indent = true;
				break;
			}
		}

		if (indent)
		{
			uint indent_level;

			indent_level = d_indent_backend.get_indent(buf, cur);

			print("indent level: %u\n", indent_level);

			var start = cur;
			start.set_line_offset(0);
			var end = start;

			var c = end.get_char();
			while (c.isspace())
			{
				if (end.ends_line() || !end.forward_char())
				{
					break;
				}

				c = end.get_char();
			}

			var indent_string = get_indent_string_from_indent_level(indent_level);

			buf.begin_user_action();
			buf.delete(ref start, ref end);

			buf.insert(ref start, indent_string, -1);
			buf.end_user_action();
		}
	}
}

}

/* vi:ex:ts=4 */
