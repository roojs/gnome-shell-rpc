#include "button-release-chain-signal.h"

guint
button_release_chain_signal (GType type)
{
	return g_signal_new (
		"phase",
		type,
		G_SIGNAL_RUN_LAST,
		0,
		g_signal_accumulator_true_handled,
		NULL,
		g_cclosure_marshal_generic,
		G_TYPE_BOOLEAN,
		0);
}
