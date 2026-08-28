/*
 * Appended to vendor shell-global.c (same translation unit) for libshell RPC
 * client builds.  Split compositor: attach MetaDisplay without MetaPlugin.
 */

#include "shell-global-rpc.h"

ShellWM *shell_wm_new (MetaPlugin *plugin);

void
shell_global_attach_rpc_display (ShellGlobal *global,
                                 MetaDisplay *display)
{
  MetaContext *context;
  MetaBackend *backend;
  MetaSettings *settings;

  g_return_if_fail (SHELL_IS_GLOBAL (global));
  g_return_if_fail (global->meta_display == NULL);
  g_return_if_fail (display != NULL);

  context = meta_display_get_context (display);
  backend = meta_context_get_backend (context);
  global->plugin = NULL;
  global->wm = shell_wm_new (NULL);

  global->meta_display = display;
  global->compositor = meta_display_get_compositor (display);
  global->meta_context = meta_display_get_context (display);
  global->backend = meta_context_get_backend (context);
  global->workspace_manager = meta_display_get_workspace_manager (display);

  global->stage = CLUTTER_STAGE (meta_backend_get_stage (global->backend));

  st_entry_set_cursor_func (entry_cursor_func, global);
  st_clipboard_set_selection (meta_display_get_selection (display));

  g_signal_connect (global->stage, "notify::width",
                    G_CALLBACK (global_stage_notify_width), global);
  g_signal_connect (global->stage, "notify::height",
                    G_CALLBACK (global_stage_notify_height), global);

  clutter_threads_add_repaint_func (CLUTTER_REPAINT_FLAGS_PRE_PAINT,
                                    global_stage_before_paint,
                                    global, NULL);

  g_signal_connect (global->stage, "after-paint",
                    G_CALLBACK (global_stage_after_paint), global);

  clutter_threads_add_repaint_func (CLUTTER_REPAINT_FLAGS_POST_PAINT,
                                    global_stage_after_swap,
                                    global, NULL);

  shell_perf_log_define_event (shell_perf_log_get_default (),
                               "clutter.stagePaintStart",
                               "Start of stage page repaint",
                               "");
  shell_perf_log_define_event (shell_perf_log_get_default (),
                               "clutter.paintCompletedTimestamp",
                               "Paint completion on GPU",
                               "");
  shell_perf_log_define_event (shell_perf_log_get_default (),
                               "clutter.stagePaintDone",
                               "End of frame, possibly including swap time",
                               "");

  backend = meta_context_get_backend (shell_global_get_context (global));
  settings = meta_backend_get_settings (backend);
  g_signal_connect (settings, "ui-scaling-factor-changed",
                    G_CALLBACK (ui_scaling_factor_changed), global);

  global->focus_manager = st_focus_manager_get_for_stage (global->stage);

  update_scaling_factor (global, settings);
}
