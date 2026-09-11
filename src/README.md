# Source layout (`src/`)

Builds **`mutter-rpc`** (compositor + OLLMrpc **server** + **Helper** relays) and **`gnome-shell-rpc`** (GJS + client typelibs). Meson: [`meson.build`](meson.build).

**What RPCs:** stock-shaped **Meta**, **Clutter**, **St**, and **Shell** GI calls over one socket — not “mutter-only”. Names like **`libmutter-rpc-16`** and **`mutter-rpc`** are legacy; see [0.7.10](../docs/plans/0.7.10-src-directory-layout.md#what-actually-goes-over-rpc).

**Overrides vs server:** client **`gi-stub/overrides*`**, **`overrides-clutter*`**, **`overrides-st*`** only; server uses **`rpc/helper/*`** (no `*.override.vala`). Per-library table + sample files: [Per-library map](../docs/plans/0.7.10-src-directory-layout.md#per-library-map-generator-client-overrides-server-helpers).

**Planned:** [`docs/plans/0.7.10-src-directory-layout.md`](../docs/plans/0.7.10-src-directory-layout.md) — **`Gsr`** prefix (replacing **`GnomeShellRpc`**), **`client/lib*`** dirs, **`tests/meta-mini/`**, etc.

---

## **`shared/`** — code both server and client compile

**One folder** for OLLMrpc serializable types used on **both** sides. Meson lists the same **`.vala`** in **mutter-rpc** and client **lib\*** builds (and some tests).

| Today | Goes in **`shared/`**? |
| ----- | ---------------------- |
| **`shared/`** (`Rectangle`, …) | Yes — already there |
| **`ui/`** (`Window`, `Display`, `Workspace`, `Compositor`) | **Yes** — merge into **`shared/`** in [0.7.10](../docs/plans/0.7.10-src-directory-layout.md). Separate **`ui/`** is legacy from plan 0.3 (only **`Rectangle`** moved first), not a different ownership model. |

Namespace today: **`GnomeShellRpc.Shared`** vs **`GnomeShellRpc.Ui`**; after **Gsr**, likely one **`Gsr.Shared`** (TBD in the plan). Wire names stay **`Window`**, **`Rectangle`**, etc.

**Not in `shared/`:** **`Meta.Window`**, **`Rpc.Helper.Window`** — live GI / server helpers, not the shared DTOs.

**Examples:** **`Rpc.Server`** registers **`Ui.Window`**; **`gi-stub/Runtime`** registers the same type so RPC decode matches.

---

## Product pieces (today → target)

| Today | Builds | Target location |
| ----- | ------ | ----------------- |
| **`rpc/`** + **`Main.vala`**, **`Plugin.vala`** | **`mutter-rpc`** | **`server/Main.vala`**, **`server/Plugin.vala`**, **`server/rpc/`** — binary + **`Meta.Plugin`** at **`server/`** top level (no **`mutter-plugin/`** subfolder) |
| **`gi-stub/`** | **`libmutter-rpc-16`**, **`libmutter-clutter-rpc-16`**, **`libst-rpc-16`** | **`client/libmutter-rpc-16/`**, **`client/libmutter-clutter-rpc-16/`**, **`client/libst-rpc-16/`** |
| **`shell-gi/`** | **`libshell-gi-16.so`**, **Shell-16** typelib | **`client/libshell-gi-16/`** |
| **`shell-client/`** | **`gnome-shell-rpc`** executable | **`client/`** (same directory as the libs — no `client/gnome-shell-rpc/` subfolder) |
| **`shell-js/`** | **`shell-js-resources`** gresource | **`client/gresource/`** |
| **`gi-stub-gen/`** | **`gi-stub-gen`** | **`generator/`** |

---

## Harnesses (today under `src/` → `tests/`)

| Today | Binary | Target |
| ----- | ------ | ------ |
| **`meta-mini/`** | (legacy Vala + **`Meta-16.gir`**) | **`tests/meta-mini/`** |
| **`gi-rpc-mock/`** | **`gi-rpc-mock`** | **`tests/gi-rpc-mock/`** |
| **`gjs-embed/`** | **`gjs-embed`** | **`tests/gjs-embed/`** |
| **`rpc-client/`** | **`ollm-demo-client`** (rename) | **`tests/ollm-demo-client/`** |
| **`fake-shell/`** | **`fake-shell`** | **`tests/fake-shell/`** |
| **`gi-rpc-smoke/`**, **`gi-rpc-echo/`** | legacy toy | **`tests/gi-rpc-smoke/`** |

Details: [`tests/README.md`](../tests/README.md).

---

## Target tree (short)

```text
src/shared/  src/generator/
src/server/Main.vala, Plugin.vala, rpc/
src/client/
  ShellApplication.vala, …     # gnome-shell-rpc
  libmutter-rpc-16/
  libmutter-clutter-rpc-16/
  libst-rpc-16/
  libshell-gi-16/
  gresource/
tests/meta-mini/  …
```

```text
mutter-rpc  ──RPC──►  gnome-shell-rpc
  server/              client/ + client/lib*
```

---

## Related docs

- [`docs/build.md`](../docs/build.md)
- [`docs/libmutter-rpc-for-gnome-shell-js.md`](../docs/libmutter-rpc-for-gnome-shell-js.md)
- Active: [`docs/plans/0.8-init-complete-and-interaction.md`](../docs/plans/0.8-init-complete-and-interaction.md)
