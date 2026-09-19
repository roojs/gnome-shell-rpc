# gstrv-gir-gate

Product-shaped prove: valac writes `GsrSearch-1.0.gir` and **leaves it**
(never installed). `scripts/gir-inject-placeholder.sh` writes
`GsrSearch-1.0.injected.gir` — typelib and any install use that (installed
name `GsrSearch-1.0.gir`). GJS marshals `search` as `string[][]`.
Vala `ping` stays. Original GIR must still contain the placeholder.

```bash
meson compile -C build tests/gstrv-gir-gate/GsrSearch-1.0.typelib
meson test -C build gstrv-gir-gate --print-errorlogs
```

PASS: placeholder gone, nested `utf8` / `char***`, `gstrv-gir-gate: ok`.
