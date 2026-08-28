#pragma once

#include "bootstrap.h"

G_BEGIN_DECLS

void gnome_shell_rpc_shell_bootstrap_connected (void);
GjsContext *gnome_shell_rpc_get_gjs_context (void);

G_END_DECLS
