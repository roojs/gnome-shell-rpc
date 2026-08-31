/* Stage API signatures stock uses (GIR drops GError / wrong buffer types). */
gboolean clutter_stage_paint_to_buffer (ClutterStage * stage,
                                        const MtkRectangle * rect,
                                        float scale,
                                        uint8_t * data,
                                        int stride,
                                        CoglPixelFormat format,
                                        ClutterPaintFlag paint_flags,
                                        GError ** error);
ClutterContent * clutter_stage_paint_to_content (ClutterStage * stage,
                                                 const MtkRectangle * rect,
                                                 float scale,
                                                 ClutterPaintFlag paint_flags,
                                                 GError ** error);
ClutterStageView * clutter_stage_get_view_at (ClutterStage * stage,
                                              float x,
                                              float y);
