#include <glib-object.h>

/*
 * Stock Shell.PolkitAuthenticationAgent.initiate: five parameters,
 * last is G_TYPE_STRV. Vala signal registration appends an int length.
 */
void
polkit_initiate_shape_strv_agent_register_initiate(GType type)
{
	if (g_signal_lookup("initiate", type) != 0)
		return;
	g_signal_new("initiate",
		type,
		G_SIGNAL_RUN_LAST,
		0,
		NULL,
		NULL,
		NULL,
		G_TYPE_NONE,
		5,
		G_TYPE_STRING,
		G_TYPE_STRING,
		G_TYPE_STRING,
		G_TYPE_STRING,
		G_TYPE_STRV);
}
