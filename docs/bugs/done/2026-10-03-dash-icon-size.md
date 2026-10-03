# Dash icons the wrong size

**Status:** ✔️ fixed 2026-10-03. Archived. User 2026-09-30 and 2026-10-03. Was phase 6 of [`../2026-09-30-overview-boot-flicker.md`](../2026-09-30-overview-boot-flicker.md).

## Seen

App icons in the dash sat at the top of the pill. The grid button sat lower. Stock: all centred, same size.

## Cause

Construct properties are batched and sent as `Gsr-Clutter-Actor.add_properties`. The batch was flushed only when the actor was the call instance, not when it was an argument.

`BaseIcon` does `set_child(new St.BoxLayout({y_expand: true}))`. On the server that ran as `set_child`, then `y_expand`. Clutter then marks the `BaseIcon` as expanding. Stock order (`y_expand`, then `set_child`) leaves it not expanding. `BinLayout` centres a child that does not expand, and fills one that does: ours 44×68 at y=0, stock 44×44 at y=12.

Replicated in stock with a bare `Shell.SquareBin` + `St.BoxLayout({y_expand: true})`: `needs_expand` false.

## Fix

`src/client/rpc/namespace.vala` `call_value`: flush the batch of every object argument before the request.

After: `add_properties` before `set_child`. App `BaseIcon` `0,12 44x44`, `needs_expand` false, same as stock. Screenshot matches.

## Probes

- Ours: `GSR_DEBUG=1 GSR_NESTED_STAYUP=1 GI_RPC_JS_OVERRIDE_DIR=$PWD/tests/shell-js-probe/dash-icons ./scripts/weston-gsr-prove.sh`
- Stock: GNOME Shell 48 `--wayland --nested --mode=gsr-dash-probe` in its own Weston, `XDG_DATA_DIRS=tests/shell-js-probe/dash-icons/stock-data:…`, empty `XDG_CONFIG_HOME`.

Icon size itself was always right: 32px in both at 800×600.

## Side find

`clutter_actor_get_constraints` is missing from `libmutter-clutter-rpc-16.so`. Not fixed here.
