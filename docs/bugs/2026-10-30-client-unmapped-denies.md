# Methods left out of the client libraries

**Status:** ⏳ open. User 2026-10-30.

Gnome Shell looks each method up by the C function name published in Mutter or gnome-shell. Our client library has to contain that function. The names in this bug were left out, so the lookup fails when the script reaches them.

They are the bare names in the temporary section of the three deny files. A line marked `temporary` still produces a function that throws. A line marked `noop` still produces a function that does nothing. Those two stay on [Phase D](../plans/1.0-run-to-end.md). A name with neither flag is left out of the library entirely.

Checked 2026-10-30 against `build/src/libst-rpc-16.so`, `libmutter-rpc-16.so`, and `libmutter-clutter-rpc-16.so`. The methods under “Still missing” are not in those libraries.

**Done when:** each missing method is written by hand, under the C name Mutter or gnome-shell published, and its deny line sits in the permanent section with a one-line reason.

The generator cannot write these. The argument or the return is a callback, an event, a `GValue`, a Pango object, a cairo surface, a `GType`, a Cogl object, or a paint context. Write them the same way as the methods already in the permanent section. Paint and pick on the client can return immediately. The compositor does the painting, and `ImageContent.paint_content` already returns that way. Event methods can pack the short event the same way `get_current_event` does.

## Written

2026-10-31. These are in the libraries. Their deny lines are in the permanent section.

| | What the shell does | Method | C function | Caller |
| --- | --- | --- | --- | --- |
| ✔️ | Swipe tracker reads the time of the last point on a gesture. The compositor returns that event, including the time. | `GestureAction.get_last_event` | `clutter_gesture_action_get_last_event` | `vendor/gnome-shell/js/ui/swipeTracker.js` |
| ✔️ | A key the input method did not consume is put back on the compositor’s queue, marked as coming from the input method. | `InputMethod.notify_key_event` | `clutter_input_method_notify_key_event` | `vendor/gnome-shell/js/misc/inputMethod.js` |
| ✔️ | Paste asks the clipboard for its text. The compositor answers, then the callback runs. | `Clipboard.get_text` | `st_clipboard_get_text` | `vendor/gnome-shell/js/ui/shellEntry.js` |
| ✔️ | A screenshot places image bytes on the clipboard. | `Clipboard.set_content` | `st_clipboard_set_content` | `vendor/gnome-shell/js/ui/screenshot.js` |
| ✔️ | The screenshot notification builds its icon from those bytes, on the path `set_data` already uses. | `ImageContent.set_bytes` | `st_image_content_set_bytes` | `vendor/gnome-shell/js/ui/screenshot.js` |
| ✔️ | A theme node is created with its context, parent, theme, element type, and style strings. The compositor builds the node. | `ThemeNode.new` | `st_theme_node_new` | Shell C creates nodes from widgets. JavaScript reads them with `get_theme_node()`. |
| ✔️ | The notification stack paints its children newest-first. The user-name widget paints only the visible label. The client symbol returns: the lease has no paint node, and paint is not relayed. | `Actor.paint` | `clutter_actor_paint` | `vendor/gnome-shell/js/ui/messageList.js`, `vendor/gnome-shell/js/ui/userWidget.js` |
| ✔️ | The notification stack picks its children in that same order. The client symbol returns: the lease has no pick log, and pick is not relayed. | `Actor.pick` | `clutter_actor_pick` | `vendor/gnome-shell/js/ui/messageList.js` |

Copy from a text entry calls `Clipboard.set_text`. That one is generated, and it is already in the library.

`messageList.js` and `userWidget.js` also override `vfunc_paint`. `messageList.js` overrides `vfunc_pick`. Those are the virtuals. The rows above are `Actor.paint` and `Actor.pick`.

## Deny line moved

2026-10-30. The function was already in the library. The deny line is now in the permanent section.

| | Method | Where it lives |
| --- | --- | --- |
| ✔️ | `Actor.accessible` / `get_accessible` / `set_accessible` | `Actor.override`. A stand-in accessibility object until a real one exists on the server. |
| ✔️ | `GestureAction.new` | `GestureAction.override`. The constructor already creates the gesture on the compositor. |
| ✔️ | `WaylandClient.new` / `spawnv` | `WaylandClient.override.vala` |
| ✔️ | `KeyBinding.get_mask` / `get_modifiers` / `get_name` / `is_builtin` / `is_reversed` | `key-binding-wire.c`. `windowManager.js` calls `is_builtin` and `is_reversed`. |

Looked through `vendor/gnome-shell/js` and `src/client/libshell-16` on 2026-10-30. `Actor.paint` and `Actor.pick` were the real calls. They are in the Written table. Everything in the tables below does not appear there.

The shell does use the clipboard, theme nodes, the texture cache, and window frame rectangles. It does not call the missing methods on those objects. Paste uses `Clipboard.get_text`. Screenshots use `Clipboard.set_content`. Theme nodes are asked for padding, border, length, and color. The texture cache is asked for `load_file_async` and the icon-theme-changed signal. Windows are asked for `get_frame_rect`.

## Clutter methods still missing

`src/client/libmutter-clutter-rpc-16/Clutter.deny`

The shell does not call these.

| Method | C function | Why the generator skips it |
| --- | --- | --- |
| `FrameClock.get_max_render_time_debug_info` | `clutter_frame_clock_get_max_render_time_debug_info` | `GLib.String` |
| `Actor.bind_model` | `clutter_actor_bind_model` | `Gio.ListModel` and a create-child callback |
| `Actor.continue_paint` | `clutter_actor_continue_paint` | `PaintContext` |
| `Actor.continue_pick` | `clutter_actor_continue_pick` | `PickContext` |
| `Actor.get_paint_volume` | `clutter_actor_get_paint_volume` | `PaintVolume` |
| `Actor.get_transformed_paint_volume` | `clutter_actor_get_transformed_paint_volume` | `PaintVolume` |
| `Actor.pick_box` | `clutter_actor_pick_box` | `PickContext` |
| `Actor.should_pick` | `clutter_actor_should_pick` | `PickContext` |
| `BindingPool.get_for_class` | `clutter_binding_pool_get_for_class` | class pointer |
| `BindingPool.install_action` | `clutter_binding_pool_install_action` | `GObject.Callback` |
| `BindingPool.override_action` | `clutter_binding_pool_override_action` | `GObject.Callback` |
| `EOTF.get_default_luminance` | `clutter_eotf_get_default_luminance` | `Luminance` |
| `Gesture.get_point_event` | `clutter_gesture_get_point_event` | `Event` |
| `GestureAction.get_sequence` | `clutter_gesture_action_get_sequence` | `EventSequence` |
| `InputFocus.filter_event` | `clutter_input_focus_filter_event` | `Event` |
| `InputFocus.process_event` | `clutter_input_focus_process_event` | `Event` |
| `Interval.compute` | `clutter_interval_compute` | `GValue` return |
| `KeyframeTransition.get_key_frame` | `clutter_keyframe_transition_get_key_frame` | out `GValue` |
| `KeyframeTransition.set_key_frame` | `clutter_keyframe_transition_set_key_frame` | `GValue` |
| `PaintContext.get_redraw_clip` | `clutter_paint_context_get_redraw_clip` | `Mtk.Region` |
| `PaintNode.paint` | `clutter_paint_node_paint` | `PaintContext` |
| `PaintVolume.copy` | `clutter_paint_volume_copy` | `PaintVolume` |
| `PaintVolume.union` | `clutter_paint_volume_union` | `PaintVolume` |
| `PipelineCache.set_pipeline` | `clutter_pipeline_cache_set_pipeline` | `Cogl.Pipeline`, `ColorState` |
| `PipelineCache.unset_all_pipelines` | `clutter_pipeline_cache_unset_all_pipelines` | `PipelineGroup` |
| `Primaries.ensure_normalized_range` | `clutter_primaries_ensure_normalized_range` | struct method |
| `Seat.query_state` | `clutter_seat_query_state` | out `Graphene.Point`, `EventSequence` |
| `ShaderEffect.set_uniform_value` | `clutter_shader_effect_set_uniform_value` | `GValue`. Shell JavaScript calls `set_uniform_float`, which is a different function. |
| `Stage.get_device_actor` | `clutter_stage_get_device_actor` | `EventSequence` |
| `Stage.handle_event` | `clutter_stage_handle_event` | `Event` |
| `Stage.pointing_input_foreach` | `clutter_stage_pointing_input_foreach` | foreach callback |
| `Text.set_preedit_string` | `clutter_text_set_preedit_string` | `Pango.AttrList` |
| `Timeline.set_progress_func` | `clutter_timeline_set_progress_func` | progress callback |
| `value_dup_paint_node` | `clutter_value_dup_paint_node` | `GValue` / `PaintNode` |
| `value_get_paint_node` | `clutter_value_get_paint_node` | `GValue` / `PaintNode` |
| `value_set_paint_node` | `clutter_value_set_paint_node` | `GValue` / `PaintNode` |
| `value_take_paint_node` | `clutter_value_take_paint_node` | `GValue` / `PaintNode` |

## St methods still missing

`src/client/libst-rpc-16/St.deny`

The shell does not call these.

| Method | C function | Why the generator skips it |
| --- | --- | --- |
| `Clipboard.get_content` | `st_clipboard_get_content` | content callback |
| `IconColors.equal` | `st_icon_colors_equal` | `IconColors` |
| `IconInfo.load_icon_async` | `st_icon_info_load_icon_async` | `Gio.AsyncReadyCallback` |
| `IconInfo.load_symbolic_async` | `st_icon_info_load_symbolic_async` | `IconColors` and an async callback |
| `Shadow.equal` | `st_shadow_equal` | `Shadow` |
| `Shadow.get_box` | `st_shadow_get_box` | `ActorBox` out |
| `ShadowHelper.paint` | `st_shadow_helper_paint` | `PaintNode` |
| `ShadowHelper.update` | `st_shadow_helper_update` | `PaintContext` |
| `TextureCache.load_file_to_cairo_surface` | `st_texture_cache_load_file_to_cairo_surface` | `cairo.Surface` |
| `ThemeContext.get_font` | `st_theme_context_get_font` | `Pango.FontDescription` |
| `ThemeContext.set_font` | `st_theme_context_set_font` | `Pango.FontDescription` |
| `ThemeNode.get_element_type` | `st_theme_node_get_element_type` | `GType` |
| `ThemeNode.get_font` | `st_theme_node_get_font` | `Pango.FontDescription` |
| `ThemeNodePaintState.init` | `st_theme_node_paint_state_init` | struct |
| `ThemeNodePaintState.invalidate` | `st_theme_node_paint_state_invalidate` | struct |
| `ThemeNodePaintState.invalidate_for_file` | `st_theme_node_paint_state_invalidate_for_file` | `Gio.File` |
| `ThemeNodePaintState.set_node` | `st_theme_node_paint_state_set_node` | struct |
| `Widget.paint_background` | `st_widget_paint_background` | `PaintNode`, `PaintContext` |

## One Meta method still missing

`src/client/libmutter-rpc-16/Meta.deny`

The shell does not call this. It calls `Window.get_frame_rect` instead.

| Method | C function | Why the generator skips it |
| --- | --- | --- |
| `FrameBorders.clear` | `meta_frame_borders_clear` | struct method on `FrameBorder` fields |

## How to check

List the library and look for the C function. A finished method is marked `T`, which means the library defines it. Its deny line is in the permanent section.

```bash
nm -D build/src/libst-rpc-16.so | grep st_clipboard_get_text
nm -D build/src/libmutter-clutter-rpc-16.so | grep clutter_gesture_action_get_last_event
nm -D build/src/libmutter-rpc-16.so | grep meta_frame_borders_clear
```
