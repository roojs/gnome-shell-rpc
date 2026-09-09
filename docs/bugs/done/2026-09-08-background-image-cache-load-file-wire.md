# Meta-BackgroundImageCache.load empty `-32602`

**Status:** ✔️ done (wire); soft quiet after load noted  
**Hit:** 2026-09-08 ~21:11 nested  
**Plan:** T-030  

---

## Symptom

```
Meta-BackgroundImageCache.load id=4844:   (empty)
uncaught error: oll-mrpc-rpc-error-code-quark, -32602
```

Shell exited. `get_default` OK.

## Cause

Client sent URI on **`Meta-BackgroundImageCache.load`**; GIR wants `Gio.File`. Gi convert failed.

## Fix

✔️ `Helper-BackgroundImageCache.load(s)` — URI → `File` → real `cache.load`; wait until compositor `is_loaded` (3s timeout); reject empty/missing URI.  
✔️ Client override → Helper. Real `Meta-BackgroundImage.is_loaded` via RPC (no always-true stub).  

`loaded` signal still declare-only — Helper wait means stock JS takes the `is_loaded()` true branch.

## Prove

✔️ Nested ~21:22: Helper load replies; no `-32602` abort.  
⏳ Soft: few further RPCs after load (~15s) — wallpaper Idle / chrome path.
