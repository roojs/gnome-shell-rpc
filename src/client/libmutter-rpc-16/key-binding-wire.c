/**
 * gjs calls these symbols on a {@code Meta.KeyBinding} from the typelib.
 * The stub record is one byte; the fields live beside it until
 * {@code gsr_key_binding_release}.
 */

#include <glib.h>

static __thread char *entered_name;
static __thread guint entered_modifiers;
static __thread guint entered_mask;
static __thread gboolean entered_builtin;
static __thread gboolean entered_reversed;
static __thread gboolean entered;

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
 * Vala copies the one-byte box onto the stack before the JS handler
 * runs, so {@code meta_key_binding_get_name} sees a different pointer
 * from {@code gsr_key_binding_hold}. The handler is synchronous: the
 * registered name is current until {@code gsr_key_binding_leave}.
 */
void
gsr_key_binding_enter (const char *name,
                       guint modifiers,
                       guint mask,
                       gboolean builtin,
                       gboolean reversed)
{
	g_free (entered_name);
	entered_name = g_strdup (name != NULL ? name : "");
	entered_modifiers = modifiers;
	entered_mask = mask;
	entered_builtin = builtin;
	entered_reversed = reversed;
	entered = TRUE;
}

void
gsr_key_binding_leave (void)
{
	entered = FALSE;
}

const char *
meta_key_binding_get_name (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	if (fields != NULL) {
		return fields->name;
	}
	if (entered && entered_name != NULL) {
		return entered_name;
	}
	return "";
}

guint
meta_key_binding_get_modifiers (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	if (fields != NULL) {
		return fields->modifiers;
	}
	return entered ? entered_modifiers : 0;
}

guint
meta_key_binding_get_mask (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	if (fields != NULL) {
		return fields->mask;
	}
	return entered ? entered_mask : 0;
}

gboolean
meta_key_binding_is_builtin (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	if (fields != NULL) {
		return fields->builtin;
	}
	return entered ? entered_builtin : FALSE;
}

gboolean
meta_key_binding_is_reversed (MetaKeyBinding *binding)
{
	GsrKeyBindingFields *fields = lookup (binding);
	if (fields != NULL) {
		return fields->reversed;
	}
	return entered ? entered_reversed : FALSE;
}
