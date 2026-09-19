#include "app-system-search.h"

/**
 * gsr_search_app_system_search:
 * @search_string: the search string to use
 *
 * Returns: (array zero-terminated=1) (element-type GStrv) (transfer full):
 *   groups of ids. Not scanned — GIR comes from inject.sh.
 */
char ***
gsr_search_app_system_search (const char *search_string)
{
	char **group;
	char ***results;

	group = g_new0 (char *, 3);
	group[0] = g_strdup ("foo.desktop");
	group[1] = g_strdup (search_string);
	group[2] = NULL;

	results = g_new0 (char **, 2);
	results[0] = group;
	results[1] = NULL;
	return results;
}
