/*
 * Gio.SubprocessLauncher has set_cwd but no get_cwd (glib through 2.84).
 * Layout matches gio/gsubprocesslauncher-private.h: flags, envp, cwd after
 * GObject parent. Used so Meta.WaylandClient.spawnv can put cwd on the wire.
 */

#include <gio/gio.h>

typedef struct {
  GObject parent;
  GSubprocessFlags flags;
  char **envp;
  char *cwd;
} GsrSubprocessLauncherLayout;

const char *
gsr_subprocess_launcher_peek_cwd (GSubprocessLauncher *self)
{
  if (self == NULL) {
    return NULL;
  }
  return ((GsrSubprocessLauncherLayout *) self)->cwd;
}
