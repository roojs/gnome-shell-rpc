ClutterPaintContext * clutter_paint_context_new_for_framebuffer (CoglFramebuffer * framebuffer,
                                                                 const MtkRegion * redraw_clip,
                                                                 ClutterPaintFlag paint_flags,
                                                                 ClutterColorState * color_state);
ClutterColorState * clutter_paint_context_get_color_state (ClutterPaintContext * paint_context);
ClutterStageView * clutter_paint_context_get_stage_view (ClutterPaintContext * paint_context);
