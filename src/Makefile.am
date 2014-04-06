geditcodeassistanceplugin_LTLIBRARIES = src/libcodeassistance.la

gedit_plugin_vala_sources =					\
	src/gca-plugin.vala					\
	src/gca-app-activatable.vala				\
	src/gca-view-activatable.vala				\
	src/gca-window-activatable.vala				\
	src/gca-source-location.vala				\
	src/gca-source-range.vala				\
	src/gca-source-range-support.vala			\
	src/gca-expand-range.vala				\
	src/gca-source-index.vala				\
	src/gca-view.vala					\
	src/gca-document.vala					\
	src/gca-scrollbar-marker.vala				\
	src/gca-backend.vala					\
	src/gca-backend-manager.vala				\
	src/gca-unsaved-file.vala				\
	src/gca-semantic-value.vala				\
	src/gca-semantic-value-support.vala			\
	src/gca-symbol-browser.vala				\
	src/gca-symbol-browser-support.vala			\
	src/gca-diagnostic.vala					\
	src/gca-diagnostics.vala				\
	src/gca-diagnostic-colors.vala				\
	src/gca-diagnostic-tags.vala				\
	src/gca-diagnostic-message.vala				\
	src/gca-dbus.vala					\
	src/gca-remote-service.vala				\
	src/gca-log.vala					\
	src/gca-indent-backend.vala

gedit_plugin_libcodeassistance_NOINSTHFILES =			\
	src/gca-utils-c.h

EXTRA_DIST += $(gedit_plugin_libcodeassistance_NOINSTHFILES)

src_libcodeassistance_la_SOURCES =		\
	$(gedit_plugin_vala_sources)				\
	src/gca-utils-c.c

src_libcodeassistance_la_VALAFLAGS =				\
	--vapidir $(builddir)/vapi				\
	--header src/gca.h					\
	--vapi src/gca.vapi					\
	--library libcodeassistance				\
	--pkg gio-unix-2.0					\
	--pkg gee-0.8						\
	--pkg gca-utils						\
	--pkg gedit						\
	--pkg libpeas-1.0					\
	--pkg gobject-introspection-1.0				\
	--pkg config						\
	--target-glib=2.36					\
	--thread

if ENABLE_DEBUG
src_libcodeassistance_la_VALAFLAGS += --debug
endif

src_libcodeassistance_la_CFLAGS = $(GEDIT_CFLAGS) -I$(top_srcdir) -w
src_libcodeassistance_la_LDFLAGS = -module -shared -avoid-version $(GEDIT_LIBS)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = 	\
	src/gca.vapi

gcahdir = $(prefix)/include/gedit-$(GEDIT_API_VERSION)/gca
gcah_HEADERS = src/gca.h

CLEANFILES +=							\
	$(gedit_plugin_vala_sources:.vala=.c) 			\
	$(srcdir)/src_libcodeassistance_la_vala.stamp

GITIGNOREFILES +=						\
	src/$(DEPDIR)						\
	src/gca.vapi			\
	src/*.lo						\
	src/*.o							\
	src/.libs						\
	src/.dirstamp

GITIGNOREDEPS += src/Makefile.am
