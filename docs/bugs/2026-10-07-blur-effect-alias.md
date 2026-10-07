# Shell-BlurEffect alias drops the client

**Status:** ✔️ applied. `shell-blur-alias-gate` prints `PASS`. Not proven on a login.

## Problem

🔷 The shell died during the 14:31 login. A new `gsr-client` was spawned at 14:44:58.

🔷 Expected: creating a blur effect and reading it back with `get_effect` keeps the client connected.

🔷 Actual: `gsr-client` 11267 disconnected at 14:39:04 and the server logged `client exited` at 14:39:05. No kernel trap. No new file under `/var/crash`.

## Evidence

ℹ️ `alan@192.168.88.197`. Binaries mtime 14:31:32. `gsr-server` 10944, `gsr-client` 11267.

✔️ Server, in order:

- `Gsr-Shell-BlurEffect.create` id 28316
- three `Shell-BlurEffect.set_property` calls, each `RPC dispatch: no handler for 'Shell-BlurEffect'`
- client then `Clutter-Actor.get_effect` id 28343

✔️ Client on that `get_effect`:

```text
Unrecognized type alias: Shell-BlurEffect
disconnect abort Clutter-Actor.get_effect id=28343
```

✔️ Same shape as [`done/2026-09-21-shell-glsleffect-bin-alias.md`](done/2026-09-21-shell-glsleffect-bin-alias.md). `get_effect` writes the runtime alias. `Bin.register("Shell-BlurEffect")` is that alias. The client Bin map has no `Shell-BlurEffect`.

✔️ Off the shell, `tests/call-sync-repro/shell-blur-alias-gate` uses that registration and returns the leaf as a `Clutter-Effect` value. The client registers only `Clutter-Effect`. Run 2026-10-07:

```text
WARNING: Unrecognized type alias: Shell-BlurEffect
WARNING: disconnect abort BlurAliasGate.make id=2
FAIL shell-blur-alias-gate: Client: disconnected
```

Exit 1.

## Root cause

✔️ `src/server/libshell-16/BlurEffect.vala` `rpc_register` puts a Shell name on the compositor. `get_effect` encodes the peer as `Shell-BlurEffect`. Unpacking that name disconnects the client.

✔️ The calls are not generated GI and not gnome-shell JS. `src/client/libshell-16/BlurEffect.vala` sends them. `create` is already `Gsr-Shell-BlurEffect.create`. The six property writes are hard-coded `Shell-BlurEffect.set_property`.

✔️ The server half of that name is `Bin.register("Shell-BlurEffect")` in `src/server/libshell-16/BlurEffect.vala`. There is no `Request.add_class("Shell-BlurEffect")`, so `set_property` has no handler. `get_effect` still writes the registered name, and that is the disconnect.

🔷 `Shell-BlurEffect` does not belong on the server. The client class stays `Shell.BlurEffect` so GJS can construct it. The compositor peer is `Gsr-Shell-BlurEffect`, and the wire type is `Clutter-Effect`.

🚫 Register `Shell-BlurEffect` on the client to swallow the name. That keeps a Shell type on mutter, which the GLSL fix rejected.

🚫 A null check or a caught error around `get_effect`. The reply is the wrong name.

## Proposed fix

💩 Same contract as `GLSLEffect`: the wire name is the Clutter parent the client already has, methods live on `Gsr-Shell-BlurEffect`, and the client `register_handle`s the lease so `get_effect` returns that object.

🔷 Do not name an RPC `set_property`. That is `GObject.set_property`. A handler with that name on `BlurEffect` hides it, and the body cannot call it to store the value.

💩 Radius, brightness, and mode already have setters that repaint. The RPC names are those fields: `set_radius`, `set_brightness`, `set_mode`. Each assigns that property.

🚫 One `set_property(Request)` that forwards to `GObject.set_property`.

#### Remove

```vala
		/**
		 * GObject props — client syncs via stock {@code Shell-BlurEffect.set_property}
		 * (no Helper setters).
		 */
```

#### Replace with

```vala
		/**
		 * GObject props. Client setters call {@code Gsr-Shell-BlurEffect.set_radius},
		 * {@code set_brightness}, and {@code set_mode}.
		 */
```

#### Remove

```vala
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Shell-BlurEffect", typeof(BlurEffect));
			OLLMrpc.Request.add_class(
				"Gsr-Shell-BlurEffect", typeof(BlurEffect),
				"create", "",
				null
			);
		}
```

🔷 Do not `register_alias("Clutter-Effect", typeof(BlurEffect))`. That maps the peer GType onto the stub name. The peer is not `Clutter.Effect`. `register_alias` does not change what the client constructs for that name; it only makes this GType encode as it. `get_effect` is already declared `Clutter.Effect`, so an unregistered peer encodes as that without the alias.

🚫 `Bin.register("Shell-BlurEffect")` and `register_alias("Clutter-Effect", typeof(BlurEffect))`.

#### Replace with

```vala
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Shell-BlurEffect", typeof(BlurEffect),
				"create", "",
				"sync_radius", "i",
				"sync_brightness", "f",
				"sync_mode", "i",
				null
			);
		}
```

`src/server/libshell-16/BlurEffect.vala`. Add next to `create`:

#### Add

```vala
		public void sync_radius(OLLMrpc.Request request, int radius)
		{
			var effect = (BlurEffect) request.connection.leases.get(
				(int) request.lease_id);
			effect.radius = radius;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void sync_brightness(OLLMrpc.Request request, float brightness)
		{
			var effect = (BlurEffect) request.connection.leases.get(
				(int) request.lease_id);
			effect.brightness = brightness;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void sync_mode(OLLMrpc.Request request, int mode)
		{
			var effect = (BlurEffect) request.connection.leases.get(
				(int) request.lease_id);
			effect.mode = mode;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
```

`src/client/libshell-16/BlurEffect.vala`. The six `Shell-BlurEffect.set_property` calls become the matching method. Radius:

#### Remove

```vala
					Gsr.Client.Rpc.call_value("Shell-BlurEffect.set_property", this,
						OLLMrpc.args("si", "radius", this.priv_radius));
```

#### Replace with

```vala
					Gsr.Client.Rpc.call_value("Gsr-Shell-BlurEffect.sync_radius", this,
						OLLMrpc.args("i", this.priv_radius));
```

💩 The Vala property setter is already `set_radius`. An RPC method with that name does not compile. The wire names are `sync_radius`, `sync_brightness`, and `sync_mode`. Each assigns the property.

Brightness uses `sync_brightness` and `OLLMrpc.args("f", this.priv_brightness)`. Mode uses `sync_mode` and `OLLMrpc.args("i", (int) this.priv_mode)`. Same replacement in `construct`. The file comment that names `Shell-BlurEffect.set_property` names these three methods instead.

After `this.rpc_lid = response.args.get(0).get_uint64();`:

#### Add

```vala
			Gsr.Client.Rpc.register_handle(this);
```

`tests/gi-rpc-mock/HelperMock.vala` mints the create lease from the name `Shell-BlurEffect`. The reply is still a `uint64`. The stand-in object is the declared `Clutter.Effect` stub, not an alias of the peer. `sync_radius`, `sync_brightness`, and `sync_mode` are handled on `Gsr-Shell-BlurEffect`.

#### Remove

```vala
				case "Gsr-Shell-BlurEffect":
					if (name == "create") {
						this.reply_args_lease(request, "Shell-BlurEffect");
						return true;
					}
					/* Props: stock Shell-BlurEffect.set_property — not Helper. */
					break;
```

#### Replace with

```vala
				case "Gsr-Shell-BlurEffect":
					switch (name) {
						case "create":
							this.reply_args_lease(request, "Clutter-Effect");
							return true;
						case "sync_radius":
						case "sync_brightness":
						case "sync_mode":
							this.reply_void(request);
							return true;
					}
					break;
```

`tests/call-sync-repro/shell-blur-alias-gate.vala` drops the leaf registration. The declared return stays `Clutter-Effect`. No alias.

#### Remove

```vala
		OLLMrpc.Bin.register("Shell-BlurEffect", typeof(EffectBlur));
```

## Attempts

✔️ Gate added. With `Bin.register("Shell-BlurEffect")` it failed: `Unrecognized type alias: Shell-BlurEffect`.

✔️ Applied. No type registration for the peer. Methods are `Gsr-Shell-BlurEffect.sync_radius`, `sync_brightness`, `sync_mode`. Gate now prints `PASS shell-blur-alias-gate: effect unpacked`.

⏳ 🔷 A login still has to show `get_effect` without `Unrecognized type alias: Shell-BlurEffect`.
