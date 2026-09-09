# St-Icon.get_icon_name → GJS malformed UTF-8 / int-null unpack

**Status:** ✔️ fixed — generator accepts RPC int `0` as `""` (live ~19:56)  
**Hit:** 2026-09-08  
**Plan:** T-030 soft gap (quick settings)  
**Upstream wire:** libocrpc null UTF8/FILENAME OUT = `int 0` (not STRING null / `""`)  
**Upstream log:** `/home/alan/gitlive/OLLMchat/docs/bugs/2026-09-08-gi-utf8-return-still-malformed-after-null-coalesce.md`

---

## Contract

libocrpc packs null UTF8/FILENAME returns as **`int 0`**. Stub gen unpacks:

```vala
if (response.retval.type() == typeof(int) && response.retval.get_int() == 0) {
    return "";
}
return response.retval.get_string();
```

Same idea as null object → `INVALID` retval. Change is in `src/gi-stub-gen/Generator.vala` `emit_value_get` (UTF8/FILENAME).

## History

- Null STRING GValue → GJS `malformed UTF-8`
- Server coalesce / empty string still blew up on client
- OPC int-null → `G_VALUE_HOLDS_STRING` failed until generator unpack

## Not this bug

- ThemeContext `theme is null` (done).
- Soft `util_*` / Global (ported).
- Quick settings `get_accessible() is null` (follow-on).
