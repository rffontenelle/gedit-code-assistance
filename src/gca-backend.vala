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

namespace Gca
{

class Backend : Object
{
	private Gee.ArrayList<View> d_views;
	private Gee.HashMap<string, View> d_paths;
	private string d_name;
	private DBus.Service d_service;
	private DBus.Project d_project;
	private RemoteServices d_supported_services;

	public static async Backend create(string language) throws Error
	{
		var name = "org.gnome.CodeAssist.v1." + language;
		var path = "/org/gnome/CodeAssist/v1/" + language;

		var project = yield get_project(name, path);
		var services = yield get_remote_services(name, path);
		var service = yield Bus.get_proxy<DBus.Service>(BusType.SESSION, name, path);

		return new Backend(name, service, project, services);
	}

	private static async RemoteServices get_remote_services(string name, string path) throws Error
	{
		RemoteServices ret = 0;

		var intro = yield Bus.get_proxy<DBus.Introspectable>(BusType.SESSION, name, path + "/document");
		var xml = yield intro.Introspect();

		var node = new DBusNodeInfo.for_xml(xml);

		foreach (var iface in node.interfaces)
		{
			ret |= RemoteServices.parse(iface.name);
		}

		return ret;
	}

	private static async DBus.Project? get_project(string name, string path) throws Error
	{
		var intro = yield Bus.get_proxy<DBus.Introspectable>(BusType.SESSION, name, path);
		var xml = yield intro.Introspect();

		var serviceintro = new DBusNodeInfo.for_xml(xml);

		DBus.Project? project = null;

		if (serviceintro.lookup_interface("org.gnome.CodeAssist.v1.Project") != null)
		{
			project = yield Bus.get_proxy<DBus.Project>(BusType.SESSION, name, path);
		}

		return project;
	}

	private Backend(string name, DBus.Service service, DBus.Project? project, RemoteServices services)
	{
		d_name = name;
		d_service = service;
		d_project = project;

		d_views = new Gee.ArrayList<View>();
		d_paths = new Gee.HashMap<string, View>();

		d_supported_services = services;
	}

	public bool supports(RemoteServices services)
	{
		return (d_supported_services & services) != 0;
	}

	public void register(View view)
	{
		lock(d_views)
		{
			d_views.add(view);
		}

		d_paths[view.document.path] = view;

		view.changed.connect(on_view_changed);
		view.path_changed.connect(on_view_path_changed);
	}

	private new void dispose(string path)
	{
		d_service.dispose.begin(path, (obj, res) => {
			try
			{
				d_service.dispose.end(res);
			} catch {}
		});
	}

	public void unregister(View view)
	{
		dispose(view.document.path);

		view.changed.disconnect(on_view_changed);
		view.path_changed.disconnect(on_view_path_changed);

		lock (d_views)
		{
			d_views.remove(view);
		}

		d_paths.unset(view.document.path);
	}

	private void on_view_path_changed(View view, string? prevpath)
	{
		if (prevpath != null)
		{
			d_paths.unset(prevpath);
			dispose(prevpath);
		}

		d_paths[view.document.path] = view;
	}

	private async string? unsaved_document(View v)
	{
		var doc = v.document;

		if (doc.is_modified)
		{
			try
			{
				return yield doc.unsaved_data_path();
			}
			catch (Error e)
			{
				Log.debug("Failed to get unsaved document: %s", e.message);
			}
		}

		return null;
	}

	private async DBus.OpenDocument[] open_documents(View primary)
	{
		View[] views;

		lock(d_views)
		{
			views = d_views.to_array();
		}

		var ret = new DBus.OpenDocument[views.length];
		ret.length = 0;

		foreach (var v in views)
		{
			var doc = v.document;
			if (doc == null)
			{
				// This happens when a document has been closed while we're
				// iterating over open views.
				continue;
			}

			var dp = yield unsaved_document(v);

			ret += DBus.OpenDocument() {
				path = doc.path,
				data_path = (dp == null ? "" : dp)
			};
		}

		return ret;
	}

	private void parse_single(View view)
	{
		unsaved_document.begin(view, (obj, res) => {
			var data_path = unsaved_document.end(res);
			var path = view.document.path;
			var cursor = view.document.cursor;

			var options = new HashTable<string, Variant>(str_hash, str_equal);

			if (data_path == null)
			{
				data_path = path;
			}

			var dbuscurs = DBus.SourceLocation() {
				line = cursor.line,
				column = cursor.column
			};

			d_service.parse.begin(path, data_path, dbuscurs, "", options, (obj, res) => {
				ObjectPath ret;

				try
				{
					ret = d_service.parse.end(res);
				}
				catch (Error e)
				{
					Log.debug("Failed to parse: %s", e.message);
					return;
				}

				view.update(new RemoteDocument(d_name, ret));
			});
		});
	}

	private void parse_project(View view)
	{
		open_documents.begin(view, (obj, res) => {
			var docs = open_documents.end(res);

			var path = view.document.path;
			var cursor = view.document.cursor;

			var options = new HashTable<string, Variant>(str_hash, str_equal);

			var dbuscurs = DBus.SourceLocation() {
				line = cursor.line,
				column = cursor.column
			};

			d_project.parse_all.begin(path, docs, dbuscurs, "", options, (obj, res) => {
				DBus.RemoteDocument[] ret;

				try
				{
					ret = d_project.parse_all.end(res);
				}
				catch (Error e)
				{
					Log.debug("Failed to parse: %s", e.message);
					return;
				}

				foreach (var d in ret)
				{
					if (d_paths.has_key(d.path))
					{
						var vw = d_paths[d.path];
						vw.update(new RemoteDocument(d_name, d.remote_path));
					}
				}
			});
		});
	}

	private void parse(View view)
	{
		if (d_project != null)
		{
			parse_project(view);
		}
		else
		{
			parse_single(view);
		}
	}

	private void on_view_changed(View view)
	{
		parse(view);
	}
}

}

/* vi:ex:ts=4 */
