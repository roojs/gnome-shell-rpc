#include <stdlib.h>
#include <string.h>

#ifdef GATE_GI2
#include <girepository/girepository.h>
#else
#include <girepository.h>
#endif
#include <gjs/gjs.h>

/*
 * gsr-client links libgirepository-1.0 and, through libgjs, libgirepository-2.0.
 * Both register a GType named GIRepository. The 1.0 require in prepare_host
 * runs first. gjs_context_new then hits
 * "cannot register existing type 'GIRepository'".
 *
 * Build the failing path with gobject-introspection-1.0.
 * Build the fix with -DGATE_GI2 and girepository-2.0 only.
 */

static int saw_girepository;

static void
on_log(const char *domain, GLogLevelFlags level, const char *message, void *user_data)
{
	if (message != NULL &&
		strstr(message, "cannot register existing type 'GIRepository'") != NULL) {
		g_printerr("gi-repository-gate: miss\n");
		_exit(1);
	}
	g_log_default_handler(domain, level, message, user_data);
}

int
main(void)
{
	GError *error = NULL;
	GjsContext *ctx;

	g_log_set_default_handler(on_log, NULL);
#ifdef GATE_GI2
	GIRepository *repo = gi_repository_dup_default();
	gi_repository_require(repo, "Gio", "2.0", GI_REPOSITORY_LOAD_FLAG_NONE, &error);
#else
	g_irepository_require(g_irepository_get_default(), "Gio", "2.0", 0, &error);
#endif
	if (error != NULL) {
		g_printerr("gi-repository-gate: require failed: %s\n", error->message);
		return 2;
	}
	ctx = gjs_context_new();
	if (saw_girepository) {
		g_printerr("gi-repository-gate: miss\n");
		return 1;
	}
	if (ctx == NULL) {
		g_printerr("gi-repository-gate: gjs context is null\n");
		return 2;
	}
	g_object_unref(ctx);
	g_print("gi-repository-gate: ok\n");
	return 0;
}
