# Tests and harnesses

Everything here is **not** the nested product path (**`mutter-rpc`** + **`gnome-shell-rpc`** only).

Plan: [`docs/plans/0.7.10-src-directory-layout.md`](../docs/plans/0.7.10-src-directory-layout.md).

| Path (target) | What it is | Today |
| ------------- | ---------- | ----- |
| **`meta-mini/`** | Hand **`Meta-16.gir`** + legacy Vala used by old smokes / optional builds | `src/meta-mini/` |
| **`call-sync-repro/`** | Vala RPC repro | already here |
| **`gi-rpc-mock/`** | **`gi-rpc-mock`** — mock RPC **server** | `src/gi-rpc-mock/` |
| **`gjs-embed/`** | **`gjs-embed`** + `*-smoke.js` | `src/gjs-embed/` |
| **`ollm-demo-client/`** | Renamed from **`rpc-client`** | `src/rpc-client/` |
| **`fake-shell/`** | **`fake-shell`** GTK probe | `src/fake-shell/` |
| **`gi-rpc-smoke/`** | Legacy **GiRpcSmoke** / **gi-rpc-echo** | `src/gi-rpc-smoke/`, `gi-rpc-echo/` |

**Status:** “Today” column is current on disk; moves are deferred until 0.7.10 runs.
