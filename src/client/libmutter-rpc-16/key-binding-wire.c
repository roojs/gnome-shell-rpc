/**
 * gjs calls these symbols on a {@code Meta.KeyBinding} from the typelib.
 * The stub record is one byte; the fields live beside it until
 * {@code gsr_key_binding_release}.
 */

#include <glib.h>
#include <stdio.h>

static void
probe (const char *what, gpointer box, const char *name)
{
	FILE *out = fopen ("/tmp/kb-probe.txt", "a");
	if (out == NULL) {
		return;
	}
	fprintf (out, "%s box=%p name=%s\n", what, box,
		name != NULL ? name : "(null)");
	fclose (out);
}

typedef struct _MetaKeyBinding MetaKeyBinding;

typedef struct {
	char *name;
	guint modifiers;
	guint mask;
	gboolean builtin;
	gboolean reversed;
} GsrKeyBindingFields;

static GHashTable *fields_by_box;

static void
free_fields (gpointer data)
{
	GsrKeyBindingFields *fields = data;
	g_free (fields->name);
	g_free (fields);
}

static GsrKeyBindingFields *
lookup (gconstpointer box)
{
	if (fields_by_box == NULL || box == NULL) {
		return NULL;
	}
	return g_hash_table_lookup (fields_by_box, box);
}

void
gsr_key_binding_hold (gpointer box,
                      const char *name,
                      guint modifiers,
                      guint mask,
                      gboolean builtin,
                      gboolean reversed)
{
	GsrKeyBindingFields *fields;

	if (box == NULL) {
		return;
	}
	if (fields_by_box == NULL) {
		fields_by_box = g_hash_table_new_full (NULL, NULL, NULL, free_fields);
	}
	fields = g_new0 (GsrKeyBindingFields, 1);
	fields->name = g_strdup (name != NULL ? name : "");
	fields->modifiers = modifiers;
	fields->mask = mask;
	fields->builtin = builtin;
	fields->reversed = reversed;
	g_hash_table_insert (fields_by_box, box, fields);
}

void
gsr_key_binding_release (gpointer box)
{
	if (fields_by_box == NULL) {
		return;
	}
	g_hash_table_remove (fields_by_box, box);
}

/**
 * A handler callback has the registered name, not a mutter box.
 * {@code meta_key_binding_get_name} on a bare {@code KeyBinding()} is "".
 */
gpointer
gsr_key_binding_new (const char *name,
                     guint modifiers,
                     guint mask,
                     gboolean builtin,
                     gboolean reversed)
{
	gpointer box = g_malloc0 (1);
	gsr_key_binding_hold (box, name, modifiers, mask, builtin, reversed);
	probe ("new", box, name);
	return box;
}

void
gsr_key_binding_free (gpointer box)
{
	gsr_key_binding_release (box);
	g_free (box);
}

const char *
meta_key_binding_get_name (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	probe ("get_name", binding, fields != NULL ? fields->name : "");
	return fields != NULL ? fields->name : "";
}

guint
meta_key_binding_get_modifiers (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	return fields != NULL ? fields->modifiers : 0;
}

guint
meta_key_binding_get_mask (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	return fields != NULL ? fields->mask : 0;
}

gboolean
meta_key_binding_is_builtin (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	return fields != NULL ? fields->builtin : FALSE;
}

gboolean
meta_key_binding_is_reversed (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	return fields != NULL ? fields->reversed : FALSE;
}
