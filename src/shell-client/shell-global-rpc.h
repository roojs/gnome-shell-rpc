#pragma once

#include "shell-global.h"

G_BEGIN_DECLS

/**
 * Wire ShellGlobal to an RPC MetaDisplay (no MetaPlugin).
 *
 * Split-compositor bootstrap: call after _shell_global_init() and
 * meta_get_display(), before loading shell JS.
 */
void shell_global_attach_rpc_display (ShellGlobal *global,
                                      MetaDisplay *display);

/**
 * _shell_global_init(NULL) + shell_global_attach_rpc_display().
 */
void gnome_shell_rpc_shell_bootstrap (MetaDisplay *display);

G_END_DECLS
