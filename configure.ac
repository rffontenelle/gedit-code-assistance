AC_PREREQ(2.63.2)

m4_define(gedit_code_assistance_major_version, 3)
m4_define(gedit_code_assistance_minor_version, 14)
m4_define(gedit_code_assistance_micro_version, 3)
m4_define(gedit_code_assistance_version, gedit_code_assistance_major_version.gedit_code_assistance_minor_version.gedit_code_assistance_micro_version)

AC_INIT([gedit-code-assistance],[gedit_code_assistance_version],[http://bugzilla.gnome.org/enter_bug.cgi?product=gnome-code-assistance],[gedit-code-assistance],[http://live.gnome.org/Gedit/Plugins])

AC_CONFIG_HEADERS(config.h)
AC_CONFIG_MACRO_DIR([m4])

AM_PROG_LIBTOOL

AM_INIT_AUTOMAKE([1.11 tar-ustar dist-xz no-dist-gzip -Wno-portability subdir-objects])
AM_MAINTAINER_MODE([enable])
AM_SILENT_RULES([yes])

AC_PROG_INSTALL
AC_PROG_MAKE_SET

AC_DEFUN([color_enable_var],
[if test "x$1" != "xyes"; then
	$2="\033@<:@31m$1\033@<:@0m"
else
	$2="\033@<:@32m$1\033@<:@0m"
fi])

AC_ARG_ENABLE([debug],
              AS_HELP_STRING([--enable-debug],[enable debug build]),
              [enable_debug=$enableval],
              [enable_debug=no])

color_enable_var("$enable_debug", [enable_debug_msg])

AM_CONDITIONAL(ENABLE_DEBUG, test "x$enable_debug" = "xyes")

AC_ARG_ENABLE([local],
              AS_HELP_STRING([--enable-local],[enable local install (in user directory)]),
              [enable_local=$enableval],
              [enable_local=no])

GEDIT_MODULES="gedit >= 3.8 gee-0.8"

AM_PROG_VALAC
PKG_PROG_PKG_CONFIG

if test "x$VALAC" = "x"; then
	AC_MSG_ERROR([Cannot find the "valac" compiler])
fi

PKG_CHECK_MODULES([GEDIT], $GEDIT_MODULES)

gedit_prefix=`$PKG_CONFIG --variable=prefix gedit`

GEDIT_GIR_DIR="$gedit_prefix/share/gedit/gir-1.0"
AC_SUBST(GEDIT_GIR_DIR)

GEDIT_API_VERSION=3.0
AC_SUBST(GEDIT_API_VERSION)

PKG_CHECK_EXISTS([
	gtksourceview-3.0 >= 3.13.90
], [
	EXTRA_VAPI_DIRS=
], [
	EXTRA_VAPI_DIRS="--vapidir \"\$(top_srcdir)/vapi-gtksourceview\""
])

AC_SUBST(EXTRA_VAPI_DIRS)

if test "x$enable_local" = "xyes"; then
	geditlibdir="$HOME/.local/share"
	geditdatadir="$HOME/.local/share"
else
	geditlibdir="${libdir}"
	geditdatadir="${datadir}"
fi

GEDIT_PLUGIN_DIR="$geditlibdir/gedit/plugins"
GEDIT_DATA_DIR="$geditdatadir/gedit/plugins"

GCA_INDENT_BACKENDS_LIBS_DIR="$GEDIT_PLUGIN_DIR/gca/indent-backends"
GCA_INDENT_BACKENDS_DATA_DIR="$GEDIT_DATA_DIR/gca/indent-backends"

GCA_LIBS_DIR="$GEDIT_PLUGIN_DIR/gca"
AC_SUBST(GCA_LIBS_DIR)

GCA_DATA_DIR="$GEDIT_DATA_DIR/gca"
AC_SUBST(GCA_DATA_DIR)

AC_SUBST(GEDIT_PLUGIN_DIR)
AC_SUBST(GEDIT_DATA_DIR)

AC_SUBST(GEDIT_CFLAGS)
AC_SUBST(GEDIT_LIBS)

AC_SUBST(GCA_INDENT_BACKENDS_LIBS_DIR)
AC_SUBST(GCA_INDENT_BACKENDS_DATA_DIR)

AC_DEFINE_UNQUOTED([GCA_INDENT_BACKENDS_DIR], "$GCA_INDENT_BACKENDS_LIBS_DIR", [Indent Backends dir])
AC_DEFINE_UNQUOTED([GCA_INDENT_BACKENDS_DATA_DIR], "$GCA_INDENT_BACKENDS_DATA_DIR", [Indent Backends data dir])
AC_DEFINE_UNQUOTED([GCA_LIBS_DIR], "$GCA_LIBS_DIR", [Library dir])
AC_DEFINE_UNQUOTED([GCA_DATA_DIR], "$GCA_DATA_DIR", [Data dir])

AC_CONFIG_FILES([
Makefile
data/codeassistance.plugin
])

AC_OUTPUT

echo -e "

Configuration:

	prefix:                 ${prefix}
	source code location:   ${srcdir}
	compiler:               ${CC}
	debug:                  $enable_debug_msg
"
