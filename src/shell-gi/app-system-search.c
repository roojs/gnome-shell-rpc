/*
 * Workaround: Vala cannot GIR-generate this type (stacked arrays).
 * Nested GStrv reaches the typelib via a nasty clutch that hacks GIR
 * generation: xsltproc + scripts/gir-inject.xsl appends search.function.gir
 * onto class AppSystem.
 */
#include "app-system-search.h"

#include <gio/gdesktopappinfo.h>

/**
 * shell_app_system_search:
 * @search_string: the search string to use
 *
 * Wrapper around g_desktop_app_info_search() that replaces results that
 * don't validate as UTF-8 with the empty string.
 *
 * Returns: (array zero-terminated=1) (element-type GStrv) (transfer full): a
 *   list of strvs.  Free each item with g_strfreev() and free the outer
 *   list with g_free().
 */
char ***
shell_app_system_search (const char *search_string)
{
	char ***results = g_desktop_app_info_search (search_string);
	char ***groups;
	char **ids;

	for (groups = results; *groups; groups++)
		for (ids = *groups; *ids; ids++)
			if (!g_utf8_validate (*ids, -1, NULL))
				**ids = '\0';

	return results;
}

/* Vala [CCode] extern — not the GI identifier. */
char ***
gsr_app_system_search_groups (const char *search_string)
{
	return shell_app_system_search (search_string);
}
