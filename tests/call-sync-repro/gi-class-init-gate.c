#include <girepository/girepository.h>

/*
 * Gi.repository() is the process repository. 2.0 assigns
 * gi_repository_dup_default() on first use. register() goes through
 * that method, so a NULL field never reaches gi_repository_require.
 */

extern GIRepository *oll_mrpc_gi_repository(void);
extern void oll_mrpc_gi_register(const char *ns, const char *version, GError **error);

int
main(void)
{
	GError *error = NULL;
	GIRepository *repo;
	GIBaseInfo *info;

	oll_mrpc_gi_register("Gio", "2.0", &error);
	if (error != NULL) {
		g_printerr("gi-repository-method-gate: register failed: %s\n", error->message);
		return 2;
	}
	repo = oll_mrpc_gi_repository();
	if (repo == NULL || !GI_IS_REPOSITORY(repo)) {
		g_printerr("gi-repository-method-gate: miss\n");
		return 1;
	}
	info = gi_repository_find_by_name(repo, "Gio", "Application");
	if (info == NULL) {
		g_printerr("gi-repository-method-gate: miss Gio.Application\n");
		return 1;
	}
	gi_base_info_unref(info);
	g_print("gi-repository-method-gate: ok\n");
	return 0;
}
