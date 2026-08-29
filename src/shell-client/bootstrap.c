#include <meta/display.h>
#include <glib-object.h>

#include "bootstrap.h"
#include "shell-global-private.h"
#include "shell-global-rpc.h"

MetaDisplay *meta_get_display (void);
void gnome_shell_rpc_gi_stub_runtime_register (void);

/* Stub GTypes from libmutter-rpc-16 (not stock libmutter). */
GType meta_context_get_type (void);
GType meta_display_get_type (void);
GType meta_compositor_get_type (void);
GType meta_backend_get_type (void);
GType meta_background_get_type (void);
GType meta_background_actor_get_type (void);
GType meta_background_content_get_type (void);
GType meta_background_group_get_type (void);

void
gnome_shell_rpc_shell_bootstrap (MetaDisplay *display)
{
  _shell_global_init (NULL);
  shell_global_attach_rpc_display (shell_global_get (), display);
}

void
gnome_shell_rpc_shell_bootstrap_connected (void)
{
  /* Runtime.register Type.from_name / GJS typelib need these initialized. */
  g_type_ensure (meta_context_get_type ());
  g_type_ensure (meta_display_get_type ());
  g_type_ensure (meta_compositor_get_type ());
  g_type_ensure (meta_backend_get_type ());
  g_type_ensure (meta_background_get_type ());
  g_type_ensure (meta_background_actor_get_type ());
  g_type_ensure (meta_background_content_get_type ());
  g_type_ensure (meta_background_group_get_type ());

  gnome_shell_rpc_gi_stub_runtime_register ();
  gnome_shell_rpc_shell_bootstrap (meta_get_display ());
}

GjsContext *
gnome_shell_rpc_get_gjs_context (void)
{
  return _shell_global_get_gjs_context (shell_global_get ());
}
