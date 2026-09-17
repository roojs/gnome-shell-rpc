# gstrv-gir-gate

Does gtk-doc `(element-type GStrv)` on a tiny C `AppSystem.search` produce a
GIR/typelib GJS can marshal? Scanner only — no Vala method, no GIR merge.

```bash
meson compile -C build tests/gstrv-gir-gate/GsrSearch-1.0.typelib
meson test -C build gstrv-gir-gate --print-errorlogs
```

PASS: GIR nested `utf8` (not gpointer) and `gstrv-gir-gate: ok`.
