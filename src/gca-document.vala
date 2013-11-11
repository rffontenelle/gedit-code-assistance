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

namespace Gca
{

public class Document : Object
{
	private Gedit.Document d_document;

	private bool d_untitled;
	private bool d_modified;
	private string? d_text;
	private File? d_location;
	private bool d_dispose_ran;
	private string? d_path;

	private File? d_unsaved_file;

	public signal void path_changed(string? previous_path);
	public signal void changed();

	private static bool s_needs_tmp_chmod = true;

	public Gedit.Document document
	{
		get { return d_document; }
	}

	public Document(Gedit.Document document)
	{
		d_document = document;

		d_untitled = d_document.is_untitled();
		d_modified = false;
		d_text = null;

		update_modified();

		d_document.modified_changed.connect(on_document_modified_changed);
		d_document.end_user_action.connect(on_document_end_user_action);
		d_document.notify["location"].connect(on_location_changed);
		d_document.notify["shortname"].connect(on_shortname_changed);
		d_document.saved.connect(on_document_saved);

		d_location = null;
		d_path = null;

		update_location();
	}

	public override void dispose()
	{
		if (!d_dispose_ran)
		{
			d_dispose_ran = true;

			d_document.modified_changed.disconnect(on_document_modified_changed);
			d_document.notify["location"].disconnect(on_location_changed);
			d_document.notify["shortname"].disconnect(on_shortname_changed);

			d_document.end_user_action.disconnect(on_document_end_user_action);
			d_document.saved.disconnect(on_document_saved);

			clear_unsaved_file();
		}

		base.dispose();
	}

	private void update_path()
	{
		var npath = path;

		if (npath != d_path)
		{
			var prevpath = d_path;
			d_path = npath;

			path_changed(prevpath);
		}
	}

	private void update_location()
	{
		if (document.is_untitled() || !document.is_local())
		{
			d_location = null;
		}
		else
		{
			d_location = document.location;
		}

		update_path();
	}

	private void update_modified()
	{
		if (d_modified == d_document.get_modified())
		{
			return;
		}

		d_text = null;
		d_modified = !d_modified;

		if (d_modified)
		{
			update_text();
		}
		else
		{
			emit_changed();
		}
	}

	protected void emit_changed()
	{
		changed();
	}

	private void clear_unsaved_file()
	{
		if (d_unsaved_file != null)
		{
			try
			{
				d_unsaved_file.delete();
			} catch {}

			d_unsaved_file = null;
		}
	}

	private void update_text()
	{
		TextIter start;
		TextIter end;

		d_document.get_bounds(out start, out end);
		d_text = d_document.get_text(start, end, true);

		clear_unsaved_file();

		emit_changed();
	}

	public File? location
	{
		get { return d_location; }
	}

	public unowned string text
	{
		get { return d_text; }
	}

	public bool is_modified
	{
		get { return d_modified; }
	}

	public SourceLocation cursor
	{
		get
		{
			var mark = d_document.get_insert();
			Gtk.TextIter iter;

			d_document.get_iter_at_mark(out iter, mark);

			return SourceLocation() {
				line = iter.get_line() + 1,
				column = iter.get_line_offset() + 1
			};
		}
	}

	public string path
	{
		owned get
		{
			if (d_location == null)
			{
				return d_document.shortname;
			}
			else
			{
				return d_location.get_path();
			}
		}
	}

	public async string? unsaved_data_path() throws IOError, Error
	{
		if (!d_modified)
		{
			return null;
		}

		if (d_unsaved_file != null)
		{
			return d_unsaved_file.get_path();
		}

		var orig = path;
		var idx = orig.last_index_of(".");
		string filename;

		if (idx != -1)
		{
			filename = "gca-unsaved-XXXXXX.%s".printf(orig[idx+1:orig.length]);
		}
		else
		{
			filename = "gca-unsaved-XXXXXX";
		}

		var cdir = Environment.get_user_cache_dir();
		var tmpdir = Path.build_filename(cdir, "gedit", "plugins", "codeassistance");
		var f = File.new_for_path(tmpdir);

		try
		{
			f.make_directory_with_parents();
		}
		catch (IOError e)
		{
			if (!(e is IOError.EXISTS))
			{
				throw e;
			}
		}

		if (s_needs_tmp_chmod)
		{
			FileUtils.chmod(tmpdir, 0700);
			s_needs_tmp_chmod = false;
		}

		var tmpfilename = Path.build_filename(tmpdir, filename);
		var tmpfile = FileUtils.mkstemp(tmpfilename);

		var ostream = new UnixOutputStream(tmpfile, true);

		try
		{
			yield ostream.write_async(d_text.data);

			uint8[1] b = {'\n'};
			yield ostream.write_async(b);
		}
		catch (IOError e)
		{
			try
			{
				f.delete();
			} catch {}

			try
			{
				ostream.close();
			} catch {}

			throw e;
		}

		ostream.close();
		d_unsaved_file = File.new_for_path(tmpfilename);

		return d_unsaved_file.get_path();
	}

	private void on_document_end_user_action()
	{
		if (d_modified)
		{
			update_text();
		}
	}

	private void on_document_modified_changed()
	{
		update_modified();
	}

	private void on_location_changed()
	{
		update_location();
	}

	private void on_document_saved()
	{
		emit_changed();
	}

	private void on_shortname_changed()
	{
		update_path();
	}
}

}

/* vi:ex:ts=4 */
