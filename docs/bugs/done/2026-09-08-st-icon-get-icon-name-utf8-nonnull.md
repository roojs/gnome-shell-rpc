# St-Icon.get_icon_name UTF-8 after set (non-null return)

**Status:** ✔️ done — generator UTF8/FILENAME dup + `owned get` / `owned string`  
**Hit:** 2026-09-08 (~20:00 / ~20:13 nested; cleared ~20:23)  
**Plan:** T-030 soft gap  
**Related (done):** [int-null unpack](done/2026-09-08-st-icon-get-icon-name-utf8.md)

---

## Symptom

After `set_icon_name('display-brightness-symbolic')`, `get_icon_name` → GJS `malformed UTF-8`.

## Server probe (`IconDiag` Helper)

✔️ C/`g_object_get` on leased `StIcon` returns **valid** UTF-8:

```
IconDiag.get … null=0 valid=1 len=27 name=display-brightness-symbolic
head_hex=64697370…6963
```

Packed with `OLLMrpc.val("s", name)` — client still throws. **Not** bad St C / not Gi.scalar inventing garbage.

## Root cause

Generated getter (transfer-none `const gchar*` via stock `cname`):

```c
_tmp8_ = g_value_get_string (&retval);
result = _tmp8_;
_g_object_unref0 (response);  /* frees the string storage */
return result;                /* dangling → GJS malformed UTF-8 */
```

Int-null path returns `""` literal — fine. Non-null path dangles.

## Fix

✔️ Generator UTF8/FILENAME unpack: copy before `Response` dies (`unowned` + `.dup()` / int-0 → `""`). Property getters `owned get`; methods `owned string`. Hand stubs (`ClutterEffectRelay`, Display pad labels) same.

Temporary `IconDiag` probe removed after prove.
