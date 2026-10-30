# Lock screen opens, password does not unlock

**Status:** ✅ closed 2026-10-30. User. Enter reaches GDM. Weston `ok submitted`. A second lock shows the password page again (`ok second-prompt`). Archived as done.

Enter calls `Spinner.play()` → `set_content(new St.SpinnerContent())`. That threw, so `answerQuery` never ran.

### 1. `src/client/libst-rpc-16/St.overrides` — `SpinnerContent` implements

**Why:** GJS accepts `set_content` only when the GType implements `Clutter.Content`.

**Where:** After the `ImageContent implements=Clutter.Content` line.

**Depends on:** none.

#### Add

After `ImageContent implements=Clutter.Content`.

```
# Stock St.SpinnerContent implements Clutter.Content. AuthPrompt spins
# this on password submit. Deny drops the iface, so GJS refuses
# Actor.set_content and the password is never answered.
SpinnerContent implements=Clutter.Content
```

### 2. `src/client/libst-rpc-16/overrides/SpinnerContent.override.vala` — lease

**Why:** `new St.SpinnerContent()` leases stock `st_spinner_content_new`. `set_content` then sends that peer. Paint stays on the server, same as `ImageContent`.

**Where:** New file. Generator splices it into class `SpinnerContent`.

**Depends on:** 1.

#### Add

New file.

```vala
		/**
		 * Stock {@code st_spinner_content_new} on the compositor.
		 * {@code new St.SpinnerContent()} from the shell leases that
		 * peer. A decode of the create reply already has
		 * {@code rpc_lid} and must not create another.
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-SpinnerContent.create", null);
			if (response.retval.type() == GLib.Type.INVALID
					|| response.retval.get_object() == null) {
				return;
			}
			var peer = response.retval.get_object() as OLLMrpc.Live.Interface;
			if (peer == null || peer.rpc_lid == 0) {
				return;
			}
			this.rpc_lid = peer.rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
		}

		/**
		 * {@link Clutter.Content.get_preferred_size} on the leased
		 * {@code StSpinnerContent}.
		 */
		public bool get_preferred_size(out float width, out float height)
		{
			width = 0;
			height = 0;
			if (this.rpc_lid == 0) {
				return false;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-SpinnerContent.get_preferred_size", this);
			if (response.args.size < 2) {
				return false;
			}
			width = (float) response.args.get(0).get_double();
			height = (float) response.args.get(1).get_double();
			return response.retval.get_boolean();
		}

		/**
		 * Paint runs on the leased spinner after
		 * {@link Clutter.Actor.set_content}. There is no client stage.
		 */
		public void paint_content(
			Clutter.Actor actor,
			Clutter.PaintNode node,
			Clutter.PaintContext paint_context
		) {
			return;
		}

		/**
		 * Stock leaves this vfunc unset. Attach is
		 * {@link Clutter.Actor.set_content} of the leased spinner.
		 */
		public void attached(Clutter.Actor actor)
		{
			return;
		}

		/**
		 * Stock leaves this vfunc unset.
		 */
		public void detached(Clutter.Actor actor)
		{
			return;
		}

		/**
		 * {@code clutter_content_invalidate} on the leased spinner.
		 */
		public void invalidate()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			Gsr.Client.Rpc.call_value("Gsr-St-SpinnerContent.invalidate", this);
		}

		/**
		 * {@code clutter_content_invalidate_size} on the leased spinner.
		 */
		public void invalidate_size()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			Gsr.Client.Rpc.call_value(
				"Gsr-St-SpinnerContent.invalidate_size", this);
		}
```

### 3. `src/server/libst-16/SpinnerContent.vala` — stock spinner

**Why:** `Gsr-St-SpinnerContent.create` calls `st_spinner_content_new` and exports it. Preferred size and invalidate call `clutter_content_*` on that lease. Mutter’s server vapi has no `Clutter.Content`, so the C prototypes use `ClutterContent*`.

**Where:** New file.

**Depends on:** none.

#### Add

New file.

```vala
/**
 * Stock {@code st_spinner_content_new}. The compositor owns the
 * spinner. It animates once {@link Clutter.Actor.set_content}
 * attaches it to a mapped actor.
 *
 * Wire prefix {@code Gsr-St-SpinnerContent}.
 */
namespace Gsr.Server.St
{
	public class SpinnerContent : GLib.Object
	{
		[CCode (cname = "st_spinner_content_new")]
		private static extern GLib.Object st_spinner_content_new();

		[CCode (cname = "clutter_content_get_preferred_size")]
		private static extern bool clutter_content_get_preferred_size(
			[CCode (type = "ClutterContent*")] void* content,
			out float width,
			out float height
		);

		[CCode (cname = "clutter_content_invalidate")]
		private static extern void clutter_content_invalidate(
			[CCode (type = "ClutterContent*")] void* content
		);

		[CCode (cname = "clutter_content_invalidate_size")]
		private static extern void clutter_content_invalidate_size(
			[CCode (type = "ClutterContent*")] void* content
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-SpinnerContent", typeof(SpinnerContent),
				"create", "",
				"get_preferred_size", "",
				"invalidate", "",
				"invalidate_size", "",
				null
			);
			OLLMrpc.Request.register_live(
				"Gsr-St-SpinnerContent", new SpinnerContent());
		}

		/**
		 * {@code Gsr-St-SpinnerContent.create} — stock
		 * {@code st_spinner_content_new}.
		 */
		public void create(OLLMrpc.Request request)
		{
			var peer = st_spinner_content_new();
			request.connection.export(peer);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", peer),
			});
		}

		/**
		 * {@code clutter_content_get_preferred_size} on the leased spinner.
		 */
		public void get_preferred_size(OLLMrpc.Request request)
		{
			var content = request.connection.leases.get((int) request.lease_id);
			if (content == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			float width = 0;
			float height = 0;
			var ok = clutter_content_get_preferred_size(content, out width, out height);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
				args = OLLMrpc.args("dd", (double) width, (double) height),
			});
		}

		/**
		 * {@code clutter_content_invalidate} on the leased spinner.
		 */
		public void invalidate(OLLMrpc.Request request)
		{
			var content = request.connection.leases.get((int) request.lease_id);
			if (content == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			clutter_content_invalidate(content);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * {@code clutter_content_invalidate_size} on the leased spinner.
		 */
		public void invalidate_size(OLLMrpc.Request request)
		{
			var content = request.connection.leases.get((int) request.lease_id);
			if (content == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			clutter_content_invalidate_size(content);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
```

### 4. `src/server/libst-16/namespace.vala` — register

**Why:** Startup must install the `Gsr-St-SpinnerContent` handler. GI already owns the `StSpinnerContent` GType, so there is no alias.

**Where:** `rpc_register`, immediately after `ImageContent.rpc_register();`.

**Depends on:** 3.

#### Add

After `ImageContent.rpc_register();`.

```vala
		SpinnerContent.rpc_register();
```

### 5. `src/meson.build` — sources

**Why:** The server binary and the St generator both need the new files.

**Where:** Server source list after `ImageContent.vala`. `st_generated` `files(` after `ImageContent.override.vala`.

**Depends on:** 2 and 3.

#### Add

After `'server/libst-16/ImageContent.vala',` in the server source list.

```meson
  'server/libst-16/SpinnerContent.vala',
```

After `'client/libst-rpc-16/overrides/ImageContent.override.vala',` in `st_generated` `files(`.

```meson
    'client/libst-rpc-16/overrides/SpinnerContent.override.vala',
```

---

## LLM efforts

**2026-10-30 15:07.** `ssh alan@192.168.122.52`. Host `alan-VirtualBox`, Ubuntu 25.04. Current boot started 14:49. Session login 15:07:12, `gsr-client` pid 6775. Client log has key-press and `St-Entry.get_text` at 15:07:25 and 15:07:37 during startup. No `unlock`, `shield`, or `AuthPrompt` line. At 15:08:15 pid 6775 SIGABRT: `gjs_value_from_array_and_length_values` `G_VALUE_HOLDS_POINTER(array_value)` from `shell_polkit_authentication_agent_auth_request_initiate`. polkitd: `com.ubuntu.release-upgrader.release-upgrade` failed to authenticate. `nm -D` on `libmutter-clutter-rpc-16.so` (mtime 15:05) shows `clutter_event_get_key_unicode`.

**2026-10-30 15:12.** Boot `-1` journal, 2026-10-30 14:45:31–14:45:38. Pointer motion on `UnlockDialog`, then two `type=1` key presses. Each key: `JS ERROR` `undefined symbol: clutter_event_get_key_unicode`. No verification line after that. That boot's library predates the 15:05 install.

**2026-10-30 15:16.** `GI_META_SMOKE=lock-screen-unlock-smoke/ui/init`, nest 70s. `canLock=true gdm=48.0`. Prompt opened. Before typing: `status=verifying len=0 hint=Password`. After Enter: `JS ERROR` `St.SpinnerContent` cannot convert to `ClutterContent` at `animation.js:36` from `_activateNext`. `miss still-locked status=in-progress len=6 reactive=false message=`. `stop` killed Weston (ec 137).

**2026-10-30 15:22.** Same smoke with `GI_RPC_JS_OVERRIDE_DIR=tests/gjs-embed/lock-screen-unlock-override` catching `set_content`. Log: `spinner-content-caught` the same TypeError, then `miss entry-empty` with `message=Sorry, password authentication didn’t work. Please try again.` The password reached GDM once the throw was swallowed.

**2026-10-30 15:24.** `SpinnerContent implements=Clutter.Content` plus the Content vfuncs. Rebuilt `libst-rpc-16.so`. Same smoke, no override. `ok submitted` with that same GDM rejection. `nested-weston-prove: stop (smoke-ok) after 17s`. No `cannot convert to ClutterContent`.

**2026-10-30 15:34.** Server `Gsr-St-SpinnerContent.create` plus `register_alias("St-SpinnerContent")`. Smoke still `ok submitted`, but the log is `uncaught error: duplicate register of type 'StSpinnerContent'` and `no handler for 'Gsr-St-SpinnerContent'`. Create never ran. GI already registers that GType.

**2026-10-30 15:36.** Alias removed. Same smoke. `Gsr-St-SpinnerContent.create` id=18764 replied, then `Clutter-Actor.set_content` id=18765 replied. `ok submitted` with the GDM rejection. `stop (smoke-ok)`.

**2026-10-30 16:07.** `GI_META_SMOKE=lock-screen-second-lock-smoke/ui/init`. First lock: `first-prompt`. Left the shield, locked again: `second-prompt` then `ok second-prompt opacity=0 active=false`. `stop (smoke-ok) after 14s`. The password page comes back. The 15:42 guest black screen was `gsr-client` pid 13668 SIGSEGV in the upgrade polkit dialog. logind recorded no lock.

**2026-10-30 16:14.** User closed this.
