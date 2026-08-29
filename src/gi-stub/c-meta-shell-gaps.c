/*
 * libshell link-time meta_* exports (plan 0.7.1).
 * X11 (#3–10): permanent noops — Wayland-only shell client.
 * #1 meta_backend_get_settings: local GObject stub (scaling signal).
 * #2 meta_settings_get_ui_scaling_factor: Vala MetaSettingsAbi (Helper RPC).
 */

#include <meta/meta-backend.h>
#include <meta/meta-settings.h>
#include <meta/meta-x11-display.h>
#include <meta/meta-x11-group.h>

#include <glib-object.h>

typedef struct {
  GObject parent;
} GsrMetaSettingsStub;

typedef struct {
  GObjectClass parent_class;
} GsrMetaSettingsStubClass;

static GObject *settings_link_stub;

G_DEFINE_TYPE (GsrMetaSettingsStub, gsr_meta_settings_stub, G_TYPE_OBJECT)

static void
gsr_meta_settings_stub_class_init (GsrMetaSettingsStubClass *klass)
{
  /* Same arity as mutter: instance only (handler gets settings + user_data). */
  g_signal_new ("ui-scaling-factor-changed",
                G_TYPE_FROM_CLASS (klass),
                G_SIGNAL_RUN_LAST,
                0,
                NULL, NULL, NULL,
                G_TYPE_NONE, 0);
}

static void
gsr_meta_settings_stub_init (GsrMetaSettingsStub *self)
{
  (void) self;
}

MetaSettings *
meta_backend_get_settings (MetaBackend *backend)
{
  (void) backend;

  if (settings_link_stub == NULL) {
    settings_link_stub = g_object_new (gsr_meta_settings_stub_get_type (), NULL);
  }

  return (MetaSettings *) settings_link_stub;
}

/* meta_settings_get_ui_scaling_factor — Vala MetaSettingsAbi.vala (Helper RPC) */

MetaX11Display *
meta_display_get_x11_display (MetaDisplay *display)
{
  (void) display;
  return NULL;
}

Display *
meta_x11_display_get_xdisplay (MetaX11Display *x11_display)
{
  (void) x11_display;
  return NULL;
}

Window
meta_x11_display_get_xroot (MetaX11Display *x11_display)
{
  (void) x11_display;
  return None;
}

void
meta_x11_display_set_stage_input_region (MetaX11Display *x11_display,
                                         XRectangle      *rects,
                                         int              n_rects)
{
  (void) x11_display;
  (void) rects;
  (void) n_rects;
}

unsigned int
meta_x11_display_add_event_func (MetaX11Display         *x11_display,
                                 MetaX11DisplayEventFunc  event_func,
                                 gpointer                 user_data,
                                 GDestroyNotify           destroy_notify)
{
  (void) x11_display;
  (void) event_func;
  (void) user_data;
  (void) destroy_notify;
  return 0;
}

void
meta_x11_display_remove_event_func (MetaX11Display *x11_display,
                                    unsigned int     id)
{
  (void) x11_display;
  (void) id;
}

GSList *
meta_group_list_windows (MetaGroup *group)
{
  (void) group;
  return NULL;
}

MetaGroup *
meta_window_x11_get_group (MetaWindow *window)
{
  (void) window;
  return NULL;
}
