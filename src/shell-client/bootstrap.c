#include <meta/display.h>

#include "bootstrap.h"
#include "shell-global-private.h"
#include "shell-global-rpc.h"

MetaDisplay *meta_get_display (void);

void
gnome_shell_rpc_shell_bootstrap (MetaDisplay *display)
{
  _shell_global_init (NULL);
  shell_global_attach_rpc_display (shell_global_get (), display);
}

void
gnome_shell_rpc_shell_bootstrap_connected (void)
{
  gnome_shell_rpc_shell_bootstrap (meta_get_display ());
}

GjsContext *
gnome_shell_rpc_get_gjs_context (void)
{
  return _shell_global_get_gjs_context (shell_global_get ());
}
