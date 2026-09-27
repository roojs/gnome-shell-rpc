#include <glib-object.h>

/*
 * g_signal_new from Vala passes class-closure offset 0. This is what a
 * non-zero offset does: emission loads the function pointer at that byte
 * of the instance class. clicked_vfunc is the first virtual, so the byte
 * is sizeof(GObjectClass).
 */
void
gsr_repro_bind_clicked_slot (GType type)
{
	guint id;
	guint offset;
	GClosure *closure;

	g_type_class_unref (g_type_class_ref (type));
	id = g_signal_lookup ("clicked", type);
	offset = sizeof (GObjectClass);
	closure = g_signal_type_cclosure_new (type, offset);
	g_signal_override_class_closure (id, type, closure);
}
