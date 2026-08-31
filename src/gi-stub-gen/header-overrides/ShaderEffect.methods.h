/* Varargs uniform setter — GIR introspectable=0; impl in c-clutter-st-abi-gaps.c */
void clutter_shader_effect_set_uniform (ClutterShaderEffect * effect,
                                        const gchar * name,
                                        GType value_type,
                                        gsize n_values,
                                        ...);
