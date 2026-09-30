/*
 * ═══════════════════════════════════════════════════════════════════════════
 * VARARGS ONLY — do not add further clutter_* exports here.
 *
 * This .c exists solely because GIR marks clutter_shader_effect_set_uniform
 * introspectable=0 (C varargs). Vala cannot emit that ABI; we unpack here and
 * RPC via gsr_clutter_shader_effect_set_uniform (Vala → Helper).
 *
 * Everything else (class methods, Stage/PaintContext gaps, signals) belongs in
 * Vala: [CCode (cname = "clutter_…")] overrides / ClutterStageAbi.vala.
 * ═══════════════════════════════════════════════════════════════════════════
 */

#include <clutter/clutter.h>

#include <stdarg.h>
#include <string.h>

void gsr_clutter_shader_effect_set_uniform (ClutterShaderEffect *effect,
                                            const gchar         *name,
                                            const gchar         *type_name,
                                            int                  n_values,
                                            const gfloat        *values);

static void
set_uniform_valist (ClutterShaderEffect *effect,
                    const gchar         *name,
                    GType                value_type,
                    gsize                n_values,
                    va_list             *args)
{
  const gchar *type_name;
  gfloat *floats;
  gsize i;

  g_return_if_fail (n_values > 0);

  type_name = g_type_name (value_type);
  floats = g_new (gfloat, n_values);

  if (value_type == CLUTTER_TYPE_SHADER_INT) {
    gint *int_values = va_arg (*args, gint *);

    for (i = 0; i < n_values; i++) {
      floats[i] = (gfloat) int_values[i];
    }
  } else if (value_type == CLUTTER_TYPE_SHADER_FLOAT
             || value_type == CLUTTER_TYPE_SHADER_MATRIX) {
    gfloat *float_values = va_arg (*args, gfloat *);

    memcpy (floats, float_values, n_values * sizeof (gfloat));
  } else if (value_type == G_TYPE_INT) {
    g_return_if_fail (n_values <= 4);

    for (i = 0; i < n_values; i++) {
      floats[i] = (gfloat) va_arg (*args, gint);
    }
  } else if (value_type == G_TYPE_FLOAT) {
    g_return_if_fail (n_values <= 4);

    for (i = 0; i < n_values; i++) {
      floats[i] = (gfloat) va_arg (*args, double);
    }
  } else {
    g_warning ("Unrecognized type '%s' (values: %d) for uniform name '%s'",
               type_name,
               (int) n_values,
               name);
    g_free (floats);
    return;
  }

  gsr_clutter_shader_effect_set_uniform (effect, name, type_name,
                                         (int) n_values, floats);
  g_free (floats);
}

void
clutter_shader_effect_set_uniform (ClutterShaderEffect *effect,
                                   const gchar         *name,
                                   GType                gtype,
                                   gsize                n_values,
                                   ...)
{
  va_list args;

  g_return_if_fail (CLUTTER_IS_SHADER_EFFECT (effect));
  g_return_if_fail (name != NULL);
  g_return_if_fail (gtype != G_TYPE_INVALID);
  g_return_if_fail (n_values > 0);

  va_start (args, n_values);
  set_uniform_valist (effect, name, gtype, n_values, &args);
  va_end (args);
}
