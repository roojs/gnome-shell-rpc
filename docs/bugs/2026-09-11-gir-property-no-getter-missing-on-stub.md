# GIR boolean properties without getters missing on client Meta stubs

> # ⚠️⚠️⚠️ AGENTS — READ THIS FIRST ⚠️⚠️⚠️
>
> ## DO NOT STOP for “status theatre”
>
> **Keep working.** Do not pause to narrate progress, summarize what you tried,
> or ask whether to continue after every prove / dead end / rebuild. Carry on
> until the bar moves or you hit a real stop (need user help, or FAIL-backed
> OPC bug — then stop). See `.cursor/rules/no-status-theatre.mdc`.

**Status:** ✔️ corridor proven 2026-09-11 — stub props + Gi `get_property` / `set_property` (libocrpc GValue → `retval`); A4 still elsewhere  
**Hit:** 2026-09-11 nested Wayland — Phase A after `notify_ready` / `READY=1`  
**Plan:** [`docs/plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md) A3/A4  
**Reject:** client `return false` fakes · JS DBus shims · `Helper-ObjectProperty` wrapping `g_object_get`/`set`

---

## Progress

| Step | State |
| ---- | ----- |
| Client overrides install GIR property names | ✔️ `MonitorManager.override.vala` / `Context.override.vala` |
| Wire = stock `Meta-*.get_property` / `set_property` (no Helper) | ✔️ |
| libocrpc Gi GValue pin / no double-wrap / fill → `retval` | ✔️ upstream ([FIXED](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-11-FIXED-gi-gvalue-property-args.md)) |
| `property-smoke` reads both bools | ✔️ `night-light-supported` / `unsafe-mode` |
| Nested bind CRITICAL (`has no property called…`) | ✔️ gone on prove |
| `startup-complete` (A4) | ⏳ still red — not this gap |

**Prove:**

```bash
GI_META_SMOKE=property-smoke \
  dbus-run-session ./build/src/mutter-rpc --debug --wayland --nested
# expect: night-light-supported=… / unsafe-mode=… / property-smoke: ok
# wire: Meta-MonitorManager.get_property / Meta-Context.get_property

./scripts/nested-init-prove.sh
rg 'has no property called' /tmp/nested-init-prove.log   # expect empty
```

Archive this write-up when A4 is green or the user confirms the property corridor alone is done.

---

## Symptom (original)

During stock `_initializeUI` / extension setup, GJS does `GObject.bind_property` (and property reads) on Meta objects. Client logs:

```text
The source object of type MetaMonitorManager has no property called 'night-light-supported'
The source object of type MetaContext has no property called 'unsafe-mode'
```

`startup-complete` is not observed. Soft CRITICAL noise; boot may continue RPC-wise (A1/A2/A5 can still pass).

---

## Stock / in-process model

On real mutter these are normal GObject properties:

| Type | Property | GIR | Accessors in GIR |
|------|----------|-----|------------------|
| `Meta.MonitorManager` | `night-light-supported` | yes (readable bool) | **none** — no `getter=` |
| `Meta.Context` | `unsafe-mode` | yes (read/write bool) | **none** — no getter/setter methods |

In-process GJS uses the GObject property table installed by mutter (`g_object_class_install_properties`). C also has private getters/setters for `unsafe-mode` (`meta_context_get/set_unsafe_mode` in private headers); night-light is property-only from GIR’s point of view. Compare `panel-orientation-managed`, which **does** have `getter="get_panel_orientation_managed"` and is already emitted as RPC.

---

## Why stubs missed them

`gi-stub-gen` `emit_object_properties` only emits a Vala property when it can wire a **GIR function** getter (and setter). If `pi.get_getter()` is null, the property is **skipped** → client GType lacks the name → `bind_property` CRITICAL.

---

## Fix that landed

1. **Client overrides** — real GIR names on the stub; getter/setter call `Meta-*.get_property` / `set_property` with property name (GValue slot omitted on get; bool on set).
2. **Gi (libocrpc)** — `GObject.Value` pin (no Value-in-Value); omitted get buffer; filled scalar on **`Response.retval`**.
3. **No** type-scoped Helper · no fake `return false` · no generator auto-emit of all no-getter props.

**Invariant:** client GType lists the GIR property names; values come from the leased compositor object via Gi.

Further no-getter props (e.g. `has-builtin-panel`) → same override pattern when hit.

---

## Related

- Generator skip: `src/gi-stub-gen/Generator.vala` `emit_object_properties`
- Smoke: `src/gjs-embed/property-smoke.js`
- Plan: 0.8 Phase A rows A3/A4
