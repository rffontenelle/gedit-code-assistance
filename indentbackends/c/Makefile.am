plugin_LTLIBRARIES += indentbackends/c/libgcaindentbackendc.la

indentbackends_c_libgcaindentbackendc_la_SOURCES =			\
	indentbackends/c/gca-c-backend.vala

indentbackends_c_libgcaindentbackendc_la_CFLAGS = $(GEDIT_CFLAGS) -I$(top_srcdir)/src
indentbackends_c_libgcaindentbackendc_la_LIBADD = $(GEDIT_LIBS)
indentbackends_c_libgcaindentbackendc_la_LDFLAGS = -module -avoid-version

indentbackends_c_libgcaindentbackendc_la_VALAFLAGS =		\
	--vapidir $(builddir)/vapi				\
	--vapidir $(builddir)/src				\
	--pkg gca						\
	--pkg gio-unix-2.0					\
	--pkg gee-0.8						\
	--pkg gca-utils						\
	--pkg gedit						\
	--pkg libpeas-1.0					\
	--target-glib=2.36					\
	--thread

plugin_in_files += indentbackends/c/gcaindentbackendc.plugin
