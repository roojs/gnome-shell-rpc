/* Extra PaintNode protos / array-arg fixes (GIR uses gpointer*). */
void clutter_paint_node_set_static_name (ClutterPaintNode * node, const char * name);
void clutter_paint_node_add_rectangles (ClutterPaintNode * node, float * coords, unsigned int n_rects);
void clutter_paint_node_add_texture_rectangles (ClutterPaintNode * node, float * coords, unsigned int n_rects);
