# Source layout (`src/`)

Two processes share one Unix socket. **`gsr-server`** (`server/`) is the Mutter
plugin: real libmutter, the RPC socket, and the server-side relays.
**`gsr-client`** (`client/`) is the shell: stock GJS, a gresource of upstream
shell JavaScript, and the client libraries that stand in for Meta, Clutter,
St, and Shell. JavaScript calls those libraries; the libraries call across
the socket.

Installed client names stay **`libmutter-rpc-16`**,
**`libmutter-clutter-rpc-16`**, **`libst-rpc-16`**, and **`libshell-16`**.
The directories under `client/` are those libraries. The directories under
`server/` (`libmutter-16/`, `libmutter-clutter-16/`, `libst-16/`,
`libshell-16/`) are the relays for the same APIs. `client/rpc/` is the small
library the other client libraries link; it sends the call and does not link
the shell.

**`shared/`** is types both sides compile (`Rectangle`, `Window`,
`Workspace`). **`generator/`** is `gi-stub-gen`. Harnesses live under
[`tests/`](../tests/README.md).

The Vala namespace is **`Gsr`**. **`Meta`**, **`Clutter`**, **`St`**, and
**`Shell`** stay on the types GJS imports.

```text
src/
  shared/                     Rectangle, Window, Workspace
  generator/                  gi-stub-gen
  server/                     gsr-server
    rpc/                      the socket
    libmutter-16/
    libmutter-clutter-16/
    libst-16/
    libshell-16/
  client/                     gsr-client
    rpc/
    libmutter-rpc-16/
    libmutter-clutter-rpc-16/
    libst-rpc-16/
    libshell-16/
    gresource/
```
