# Dash favorites launch on nested boot — no click

**Status:** ⏳ open — C class_struct must match GIR so GJS `vfunc_*` hits the real slots.  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

## Symptom

Nested session starts apps that a normal GNOME session does **not** launch.
Looks “random”; they are dash favorites. `Gio.AppInfo.launch` is in-process
(not an RPC). Launch API stays 1.0 S.27 — do not no-op it.

JS (09:40:46), no pointer pick (`get_actor_at_pos` starts ~09:41:42):

```
vfunc_clicked@appDisplay.js:3069
_redisplay@dash.js:785          // insert_child_at_index
```

`animateLaunch` → `zoomOutActor` `add_child`/`get_transformed_position`
retriggers `vfunc_clicked` (same slot, still no click).

No wire `clicked` notification. Stock `st_button.c` only emits `clicked` on
button-release after press.

## Cause

GJS `vfunc_clicked` is installed from the **typelib class-struct field
offset**, not from `g_vfunc_info_get_offset` (those are all `0xFFFF` here).

Vala `Actor.override` had extra **virtual** methods (`get_preferred_width` /
`height`, `show`, `hide`, `queue_relayout`) on top of the GIR Class slots
(`*_vfunc`). C `ClutterActorClass` grew **40 bytes** past the GIR (`class_size`
488 vs GIR last+8 448). Every `St.*` field GJS uses is then 40 bytes short:

| GIR field | GIR offset | Real C slot (with extra virtuals) |
|---|---:|---|
| `St.Widget.style_changed` | 448 | 488 |
| `St.Button.clicked` | 488 | `style_changed` |

`insert_child` maps the `St.Button` peer → `style-changed` →
`style_changed_vfunc()` → GJS `vfunc_clicked` → `AppIcon.activate()`.

`allocate` was already non-virtual for this reason (“Vala would put allocate
on a Class slot GJS never uses”). Same class of smash: extra virtuals on
`LayoutManager` (+24) and `Constraint.mint_server_lease` (+8).

## Invariant

C `GTypeQuery.class_size` == GIR `class_struct` last field offset + 8.
GJS `vfunc_*` then lands on the real C slot. Gate:
`tests/class-struct-offset-gate/`.

Hand overrides: `*_vfunc` for GIR slots, or non-virtual `[CCode cname]` for
the public method. Never an extra `virtual` on a GIR type. Per-type
construct dispatch (Constraint mint) is a `GType` map, not a Class slot.

## Not this

- Autostart / `create_launcher` as a product feature
- Press/release gate or Helper-Actor for `St.Button`
  (we were not calling `clicked_vfunc` from event relay; AppIcon minted
  `St-Button.new`)
- No-op `Gio.launch`

## Do

Drop extra virtuals (method + `[CCode cname]`, like `allocate`). Subclasses
that overrode the extra methods (`SquareBin`, `WindowPreview`, `Stack`,
`WindowPreviewLayout`) override `*_vfunc` instead. Nested boot must not
launch dash favorites.
