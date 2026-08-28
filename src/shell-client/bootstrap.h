#pragma once

#include <gjs/gjs.h>

G_BEGIN_DECLS

/** After RPC {@code Runtime.register}: init ShellGlobal and attach display. */
void gnome_shell_rpc_shell_bootstrap_connected (void);

GjsContext *gnome_shell_rpc_get_gjs_context (void);

G_END_DECLS
