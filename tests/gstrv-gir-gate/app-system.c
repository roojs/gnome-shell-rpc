/* Tiny GObject + gtk-doc search — same shape as stock shell_app_system_search.
 * GIR from g-ir-scanner on this C (no Vala method, no GIR merge). */
#include "app-system.h"

struct _GsrSearchAppSystem {
	GObject parent_instance;
};

G_DEFINE_TYPE (GsrSearchAppSystem, gsr_search_app_system, G_TYPE_OBJECT)

static void
gsr_search_app_system_init (GsrSearchAppSystem *self)
{
	(void) self;
}

static void
gsr_search_app_system_class_init (GsrSearchAppSystemClass *klass)
{
	(void) klass;
}

/**
 * gsr_search_app_system_search:
 * @search_string: the search string to use
 *
 * Returns: (array zero-terminated=1) (element-type GStrv) (transfer full): a
 *   list of strvs.  Free each item with g_strfreev() and free the outer
 *   list with g_free().
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
