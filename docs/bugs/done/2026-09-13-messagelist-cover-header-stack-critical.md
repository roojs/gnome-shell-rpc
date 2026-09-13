# messageList Cover/Header stack-position CRITICAL — done

**Status:** ✔️ FIXED  
**Hit:** 2026-09-13 nested Weston  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)

**Upstream:** [`OLLMchat/.../FIXED-live-parse-object-remints-proxy.md`](file:///home/alan/gitlive/OLLMchat/docs/bugs/done/2026-09-13-FIXED-live-parse-object-remints-proxy.md)  
**Gate:** `tests/call-sync-repro/proxy-reuse-gate` — **PASS** (2026-09-13)

---

## Symptom

```
GNOME Shell-CRITICAL **: Assertion failed: Cover has expected stack position
GNOME Shell-CRITICAL **: Assertion failed: Header has expected stack position
```

`messageList.js` `cover === this._cover` after `get_children()`.

## Cause

OPC `parse_object` reminted a new proxy per decode (no `proxies` reuse).

## Fix

1. **OPC** — reuse `Client.proxies` on live decode.  
2. **Consumer** — `Runtime.register_handle` on Actor mint so create-time
   objects are in `proxies` before the first decode (lid-only create reply
   never went through `parse_object`).

Child-getter remapping / side `by_lid` map retired after OPC PASS.

## Prove

`proxy-reuse-gate` PASS; nested prove 0 Cover/Header CRITICAL.
