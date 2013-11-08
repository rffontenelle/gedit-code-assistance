geditcodeassistanceplugin_DATA = data/codeassistance.plugin
geditcodeassistancedata_DATA = data/codeassistance.css

gsettings_SCHEMAS += data/org.gnome.gedit.plugins.codeassistance.gschema.xml

EXTRA_DIST += \
	data/codeassistance.plugin \
	data/codeassistance.css

CLEANFILES += $(geditcodeassistance_SCHEMAS)
DISTCLEANFILES += $(geditcodeassistance_SCHEMAS)

MAINTAINERCLEANFILES += $(geditcodeassistance_SCHEMAS:.xml=.valid)

GITIGNOREDEPS += data/Makefile.am
