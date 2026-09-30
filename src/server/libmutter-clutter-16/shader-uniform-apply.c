/*
 * Compositor-side apply for Helper-ShaderEffect.set_uniform (plan 0.7.2 D).
 * Rebuilds a GValue and calls stock clutter_shader_effect_set_uniform_value.
 */

#include <clutter/clutter.h>

#include <string.h>

void
gsr_helper_apply_shader_uniform (ClutterShaderEffect *effect,
                                 const gchar         *name,
                                 const gchar         *type_name,
                                 const gfloat        *floats,
                                 int                  n_values)
{
  GValue value = G_VALUE_INIT;
  int i;

  g_return_if_fail (CLUTTER_IS_SHADER_EFFECT (effect));
  g_return_if_fail (name != NULL);
  g_return_if_fail (type_name != NULL);
  g_return_if_fail (n_values > 0);
  g_return_if_fail (floats != NULL);

  if (strcmp (type_name, "gint") == 0) {
    if (n_values == 1) {
      g_value_init (&value, G_TYPE_INT);
      g_value_set_int (&value, (gint) floats[0]);
    } else {
      gint *ints = g_new (gint, n_values);

      for (i = 0; i < n_values; i++) {
        ints[i] = (gint) floats[i];
      }
      g_value_init (&value, CLUTTER_TYPE_SHADER_INT);
      clutter_value_set_shader_int (&value, n_values, ints);
      g_free (ints);
    }
  } else if (strcmp (type_name, "gfloat") == 0) {
    if (n_values == 1) {
      g_value_init (&value, G_TYPE_FLOAT);
      g_value_set_float (&value, floats[0]);
    } else {
      g_value_init (&value, CLUTTER_TYPE_SHADER_FLOAT);
      clutter_value_set_shader_float (&value, n_values, floats);
    }
  } else if (strcmp (type_name, "ClutterShaderInt") == 0) {
    gint *ints = g_new (gint, n_values);

    for (i = 0; i < n_values; i++) {
      ints[i] = (gint) floats[i];
    }
    g_value_init (&value, CLUTTER_TYPE_SHADER_INT);
    clutter_value_set_shader_int (&value, n_values, ints);
    g_free (ints);
  } else if (strcmp (type_name, "ClutterShaderFloat") == 0) {
    g_value_init (&value, CLUTTER_TYPE_SHADER_FLOAT);
    clutter_value_set_shader_float (&value, n_values, floats);
  } else if (strcmp (type_name, "ClutterShaderMatrix") == 0) {
    g_value_init (&value, CLUTTER_TYPE_SHADER_MATRIX);
    clutter_value_set_shader_matrix (&value, n_values, floats);
  } else {
    g_warning ("unknown shader uniform type %s", type_name);
    return;
  }

  clutter_shader_effect_set_uniform_value (effect, name, &value);
  g_value_unset (&value);
}
