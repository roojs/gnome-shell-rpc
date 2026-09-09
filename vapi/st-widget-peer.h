/* StWidget peer for Helper.Actor — class layout must match libst-16.so
 * (see vendor/gnome-shell/src/st/st-widget.h). Undersized class ⇒
 * "class size … smaller than the parent type's StWidget class size". */
#pragma once
#include <clutter/clutter.h>
#include <glib.h>

G_BEGIN_DECLS

typedef struct _StWidget StWidget;
typedef struct _StWidgetClass StWidgetClass;

/* Match G_DECLARE_DERIVABLE_TYPE instance (parent only; priv is private). */
struct _StWidget {
	ClutterActor parent_instance;
};

struct _StWidgetClass {
	ClutterActorClass parent_class;

	void (* style_changed) (StWidget *self);
	void (* popup_menu) (StWidget *self);
	gboolean (* navigate_focus) (StWidget *self,
		ClutterActor *from,
		int direction);
	GList *(* get_focus_chain) (StWidget *widget);
};

GType st_widget_get_type (void);

G_END_DECLS
