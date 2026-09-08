# get_constraint('align') returns null after named AlignConstraint

**Status:** ✔️ FIXED — libocrpc Gi UTF8 pin; TEMP Helper bypass removed  
**Hit:** 2026-09-08  
**Plan:** T-030 **L7**  
**Upstream:** `/home/alan/gitlive/OLLMchat/docs/bugs/2026-09-08-gi-convert-utf8-dangling-before-invoke.md`  
**Prove log:** `/tmp/mutter-rpc-l7-stock.log` (stock `set_name` + `get_constraint` → `set_factor`; no Switch `obj is null`)

---

## Symptom

```
TypeError: obj is null
  _easeActorProperty → get_constraint('align')
```

---

## Lease pairing (not the bug)

| Call | IDs | OK? |
| --- | --- | --- |
| `set_name("align")` | constraint **443** | RPC ok |
| `add_constraint` | actor **442** ← **443** | ok |
| `get_constraint("align")` | actor **442** | null (stock path) |

Same handle / same constraint. Not a wrong-lease mix-up.

---

## Validation via overrides / Helper

**1. `Helper-Constraint.set_name` / `get_name`** (mutter C on the lease, bypass
`Clutter-ActorMeta.set_name` Ffi):

```
Helper-Constraint.set_name lid=443
L7 client after Helper set_name lid=443 got="align"
```

Name **does** stick when set via Helper. Stock `Clutter-ActorMeta.set_name`
does **not** (earlier `get_name` was garbage / not `"align"`).

**2. Still broken:** Helper `set_name` + stock `Clutter-Actor.get_constraint`
→ still null / TypeError. So lookup/return on the stock Gi path is also wrong
even when the name is correct on the meta.

**3. `Helper-Constraint.lookup_constraint`** (mutter `get_constraint` + return
object via Helper export):

```
Helper-Constraint.lookup_constraint
→ replied
→ Clutter-AlignConstraint.set_factor   // ease path continues
```

No `TypeError: obj is null`. Boot continues past Panel Switch.

---

## Cause (two breaks)

1. **`Clutter-ActorMeta.set_name` Gi UTF8 IN** — **proven 2026-09-08** via
   Helper probe that calls the same `g_function_info_invoke` as
   `OLLMrpc.Gi`, with only packing changed:

   | Pack | `want` | `meta.get_name()` after invoke |
   | --- | --- | --- |
   | Like `Gi.convert`: `var val = args.get(0); slot.v_string = val.get_string();` then `val` dies | `"align"` | garbage (`���u�W`, …) |
   | Like `Ffi.pack`: pin owned copy in `ArrayList<string>` until after invoke | `"align"` | `"align"` |

   Log: `/tmp/mutter-rpc-l7-gi-probe2.log` (`L7 gi-set_name pin=false|true`).
   So mutter C is fine; **Gi leaves a dangling UTF8 pointer into invoke**.
   Fix: pin UTF8/FILENAME in `libocrpc/Gi.vala` convert (same as Ffi) —
   filed in OLLMchat (do not edit from this tree):
   `/home/alan/gitlive/OLLMchat/docs/bugs/2026-09-08-gi-convert-utf8-dangling-before-invoke.md`.

2. **`Clutter-Actor.get_constraint` Gi return** — even with a correct name on
   the meta (Helper / pinned set), stock packing returns empty/null to the
   client. Helper calling the same C API finds the constraint and returns it.

---

## TEMP bypass (in tree now)

- Client `Constraint.override`: sync name via `Helper-Constraint.set_name`
- Client `Actor.override` + deny `Actor.get_constraint`: use
  `Helper-Constraint.lookup_constraint`
- Server `Helper.Constraint`: `set_name` / `get_name` / `lookup_constraint`

Proper fix: repair ActorMeta name Ffi + Gi object return for
`get_constraint`, then remove the Helper bypass.

---

## Files

- `overrides-clutter/Constraint.override.vala`, `Actor.override.vala`
- `rpc/helper/Constraint.vala`
- `Clutter.deny` — TEMP `Actor.get_constraint`
