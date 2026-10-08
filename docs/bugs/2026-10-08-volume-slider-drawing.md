# Volume slider does not paint

**Status:** not fixed. Stopped 2026-10-08 10:42. The user looked at quick settings. The volume row is still a blank space: speaker icon and chevron, no bar.

`Slider` / `BarLevel` extend `St.DrawingArea` and draw in `vfunc_repaint`. The sync paint path and a preferred-size peer are in `src/`. Neither has painted that bar. The user said to stop.

Last smoke, private nest, 10:25, `bash /tmp/gsr-da-smoke-run.sh` (does not touch the user's hold). `tests/gjs-embed/drawing-area-smoke.js` printed `drawing-area-smoke: miss no-repaint` after `on stage size=480x64`. Server log `/tmp/gsr-da-home/.cache/gnome-shell-rpc/mutter-rpc.debug.log` has `preferred get_preferred_width` 480 and `preferred get_preferred_height` 64, then `St-DrawingArea.queue_repaint`, and no `Gsr-St-DrawingArea.paint`. `Clutter-Actor.add_child` of that actor failed: `invalid (NULL) pointer instance`.

The user's nested hold is the session they are looking at. Its 09:34 and 09:37 logs still show the earlier failure: `watch_repaint` replied, `paint` was never called, then `get_surface_size` asserted `priv->in_repaint`. Logs: `~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.debug.log` and `~/.cache/gnome-shell-rpc/mutter-rpc.debug.log`.

```bash
GI_META_SMOKE=drawing-area-smoke ./scripts/weston-gsr-prove.sh
```

## Proposal

Applied in `src/`. It did not paint the bar. The panel is still a blank space. See the status at the top.

`BarLevel` and `Slider` stay as they are. One `get_context` call per emission shares one local `Cairo.ImageSurface`, because the bar and the handle each call `get_context`. The hook reads that surface after `vfunc_repaint` returns. `cr.$dispose()` still runs in the shell.

### 1. `src/meson.build` — server cairo and the new file

**Why:** `gsr-server` has no cairo vapi. The paint helper uses `Cairo.ImageSurface`.

**Where:** `compositor_sources` list, after `server/libst-16/ImageContent.vala`. `mutter_rpc` dependencies and `vala_args`.

**Depends on:** none.

#### Add — `compositor_sources`, the line after `server/libst-16/ImageContent.vala`

New server helper.

```meson
  'server/libst-16/DrawingArea.vala',
```

#### Add — `mutter_rpc` `dependencies` array, after `dependency('gee-0.8')`

Cairo for the paint helper.

```meson
    dependency('cairo'),
```

#### Add — `mutter_rpc` `vala_args` array, after `'--pkg=gee-0.8'`

Cairo vapi for the paint helper.

```meson
    '--pkg=cairo',
```

### 2. `vapi/st-widget-peer.vapi` and `vapi/st-widget-peer.h` — `St.DrawingArea`

**Why:** The server vapi has `St.Widget` only. `get_context` and the `repaint` signal belong on `St.DrawingArea` there, so the helper calls them as Vala. No `g_signal_connect_data` binding in the helper.

**Where:** `St` namespace in the vapi, after `Widget`. Prototypes in the peer header, before `G_END_DECLS`.

**Depends on:** §1.

#### Add — `vapi/st-widget-peer.vapi`, after the `Widget` class, still inside `namespace St`

`get_context` and `repaint` for the real `StDrawingArea` type.

```vala
	[CCode (cname = "StDrawingArea", type_id = "st_drawing_area_get_type ()", cheader_filename = "st-widget-peer.h")]
	public class DrawingArea : Widget {
		public unowned Cairo.Context get_context ();
		public signal void repaint ();
	}
```

#### Add — `vapi/st-widget-peer.h`, before `G_END_DECLS`

Declarations for that vapi class. The class struct stays private in libst. This header only needs the type and `get_context`.

```c
#include <cairo.h>

typedef struct _StDrawingArea StDrawingArea;

GType st_drawing_area_get_type (void);
cairo_t *st_drawing_area_get_context (StDrawingArea *area);
```

### 3. `src/server/libst-16/DrawingArea.vala` — sync repaint paint

**Why:** The client draw has to run while `in_repaint` is set, and the pixels have to be on that context before the emission returns.

**Where:** new file. `watch_repaint` connects `global::St.DrawingArea.repaint` and `hook.emit`s. `paint` runs on the nested call from that hook and writes the memfd with `get_context`.

**Depends on:** §1, §2.

#### Add — new file `src/server/libst-16/DrawingArea.vala`

`Gsr-St-DrawingArea.watch_repaint` and `Gsr-St-DrawingArea.paint`.

```vala
/**
 * Sync {@code St.DrawingArea::repaint}. The client draws while
 * {@code in_repaint} is set, then {@link paint} copies the memfd
 * onto {@link global::St.DrawingArea.get_context} before the emission returns.
 */
namespace Gsr.Server.St
{
	public class DrawingArea : GLib.Object
	{
		private static Gee.HashMap<int, OLLMrpc.Live.Hook> repaint_hooks;

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-DrawingArea", typeof(DrawingArea),
				"watch_repaint", "t",
				"paint", "uuux",
				null
			);
			OLLMrpc.Request.register_live(
				"Gsr-St-DrawingArea", new DrawingArea());
		}

		/**
		 * ''Gsr-St-DrawingArea.watch_repaint'' — connect {@code repaint}
		 * on the leased drawing area. The handler {@code hook.emit}s
		 * and blocks until the client replies.
		 */
		public void watch_repaint(OLLMrpc.Request request, uint64 hook_id)
		{
			var area = request.connection.leases.get((int) request.lease_id)
				as global::St.DrawingArea;
			if (area == null || !request.connection.callbacks.has_key((int) hook_id)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			if (DrawingArea.repaint_hooks == null) {
				DrawingArea.repaint_hooks = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
			}
			var lid = (int) request.lease_id;
			if (DrawingArea.repaint_hooks.has_key(lid)) {
				request.reply(new OLLMrpc.Response());
				return;
			}
			var hook = request.connection.callbacks.get((int) hook_id);
			DrawingArea.repaint_hooks.set(lid, hook);
			area.repaint.connect(() => {
				hook.emit(OLLMrpc.args("t", hook.connection.export(area)));
			});
			request.reply(new OLLMrpc.Response());
		}

		/**
		 * ''Gsr-St-DrawingArea.paint'' — nested call from the client
		 * hook. Still inside {@code on_repaint}, so {@code in_repaint}
		 * is set. Paint the memfd in the context's user space.
		 */
		public void paint(
			OLLMrpc.Request request,
			uint width,
			uint height,
			uint row_stride,
			int64 nbytes
		) {
			var area = request.connection.leases.get((int) request.lease_id)
				as global::St.DrawingArea;
			var got = request.buffer != null ? request.buffer.fd : -1;
			if (area == null || got < 0 || nbytes < 1 || width < 1 || height < 1) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var buf = new uint8[nbytes];
			Posix.lseek(got, 0, Posix.SEEK_SET);
			var nread = 0;
			while (nread < nbytes) {
				var n = Posix.read(got, (void*) &buf[nread], (size_t) (nbytes - nread));
				if (n <= 0) {
					break;
				}
				nread += (int) n;
			}
			if (nread != nbytes) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			var src = new Cairo.ImageSurface.for_data(
				buf, Cairo.Format.ARGB32, (int) width, (int) height, (int) row_stride);
			unowned Cairo.Context cr = area.get_context();
			cr.set_source_surface(src, 0, 0);
			cr.paint();
			request.reply(new OLLMrpc.Response());
		}
	}
}
```

### 4. `src/server/libst-16/namespace.vala` — register the helper

**Why:** The wire class is registered with the other St helpers.

**Where:** `rpc_register`, after `ImageContent.rpc_register()`.

**Depends on:** §3.

#### Add — `rpc_register`, the line after `ImageContent.rpc_register()`

Register `Gsr-St-DrawingArea`.

```vala
		DrawingArea.rpc_register();
```

### 5. `src/client/libst-rpc-16/overrides/DrawingArea.override.vala` — local surface, then memfd

**Why:** `cairo_t` stays on the client. Both `get_context` calls in one `vfunc_repaint` share that surface. After the vfunc, the bytes go to `Gsr-St-DrawingArea.paint` before the hook replies.

**Where:** replace `get_context`. Add the field, `construct`, and `send_repaint_pixels` in the same class body.

**Depends on:** §3.

#### Remove

```vala
		/**
		 * Stock {@code st_drawing_area_get_context} — {@code cairo_t *} is
		 * not on the object wire. GJS {@code repaint} handlers call this
		 * and {@code cr.$dispose()}. Local {@link Cairo.ImageSurface} of
		 * {@link get_surface_size}; pixels stay on the client.
		 */
		public Cairo.Context get_context()
		{
			uint32 width = 0;
			uint32 height = 0;
			this.get_surface_size(out width, out height);
			var w = (int) width;
			var h = (int) height;
			if (w < 1) {
				w = 1;
			}
			if (h < 1) {
				h = 1;
			}
			var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, w, h);
			return new Cairo.Context(surface);
		}
```

#### Replace with

```vala
		Cairo.ImageSurface? repaint_surface;

		[CCode (cname = "memfd_create", cheader_filename = "sys/mman.h")]
		private static extern int memfd_create(string name, uint flags);

		/**
		 * One local surface per emission. A second {@code get_context}
		 * in the same {@code vfunc_repaint} draws on that surface.
		 * {@link send_repaint_pixels} clears it.
		 */
		public Cairo.Context get_context()
		{
			if (this.repaint_surface != null) {
				return new Cairo.Context(this.repaint_surface);
			}
			uint32 width = 0;
			uint32 height = 0;
			this.get_surface_size(out width, out height);
			var w = ((int) width).clamp(1, int.MAX);
			var h = ((int) height).clamp(1, int.MAX);
			this.repaint_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, w, h);
			return new Cairo.Context(this.repaint_surface);
		}

		construct {
			if (this.rpc_lid == 0) {
				return;
			}
			var baseline = GLib.Type.from_name("StDrawingArea");
			if (baseline == GLib.Type.INVALID) {
				return;
			}
			if (OLLMrpc.Gi.vfunc_slot(this.get_type(), "St", "DrawingArea", "repaint")
					== OLLMrpc.Gi.vfunc_slot(baseline, "St", "DrawingArea", "repaint")) {
				return;
			}
			var hook_id = Gsr.Client.Rpc.callback_bind((call) => {
				Gsr.Client.Rpc.vfunc_call_void(
					this, OLLMrpc.Gi.vfunc_offset("St", "DrawingArea", "repaint"));
				this.send_repaint_pixels();
				return null;
			});
			Gsr.Client.Rpc.call_value(
				"Gsr-St-DrawingArea.watch_repaint", this,
				OLLMrpc.args("t", hook_id));
		}

		/**
		 * After {@code vfunc_repaint}. Nested {@code Gsr-St-DrawingArea.paint}
		 * while the server is still inside the emission.
		 */
		void send_repaint_pixels()
		{
			var surface = this.repaint_surface;
			this.repaint_surface = null;
			if (surface == null) {
				return;
			}
			surface.flush();
			var width = surface.get_width();
			var height = surface.get_height();
			var stride = surface.get_stride();
			if (width < 1 || height < 1 || stride < 1) {
				return;
			}
			var nbytes = stride * height;
			var fd = memfd_create("gsr-repaint", 1);
			unowned uint8* pixels = (uint8*) surface.get_data();
			if (fd < 0 || Posix.write(fd, pixels, (size_t) nbytes) != nbytes) {
				if (fd >= 0) {
					Posix.close(fd);
				}
				return;
			}
			Posix.lseek(fd, 0, Posix.SEEK_SET);
			Gsr.Client.Rpc.call_value(
				"Gsr-St-DrawingArea.paint", this,
				OLLMrpc.args("uuux", (uint) width, (uint) height,
					(uint) stride, (int64) nbytes),
				new OLLMrpc.Live.Buffer(fd));
		}
```

### 6. `src/client/libmutter-clutter-rpc-16/overrides/Actor.override.vala` — `signal_overrides`

**Why:** An async `repaint` notification runs `vfunc_repaint` again after `in_repaint` is clear. `get_surface_size` then asserts, and the local surface is 1×1.

**Where:** `signal_overrides`, inside the `foreach`, after the `GLib.Signal.lookup` check, before `names.add`.

**Depends on:** §5.

#### Add — `signal_overrides`, before `names.add(signal_name)`

`repaint` is the sync hook in §5. Leave it out of the subscribe list.

```vala
			if (signal_name == "repaint") {
				continue;
			}
```

## Reproduction

`tests/gjs-embed/drawing-area-smoke.js` puts one `St.DrawingArea` on the stage and paints it green on the client. The compositor-side paint experiment is `/tmp/gsr-da-probe.c` (not in this tree). It connects `repaint` from an interposed `g_signal_emit` and fills the live cairo context while `in_repaint` is set.

## LLM efforts

2026-10-08. `/tmp/gsr-da-probe.c` (not in this tree) loaded with `GSR_MUTTER_RPC=/tmp/gsr-server-probe.sh` and `GI_META_SMOKE=drawing-area-smoke`. First try interposed `st_drawing_area_queue_repaint`. That symbol is called from inside `libst-16.so`, so the probe never ran. Second try interposed `g_signal_emit`, connected `repaint` before the real emission, and painted the context `get_context` returned.

```text
da-probe: repaint 480 x 64 cr=0x5a26a7a1e330
da-probe: surface 480 x 64 stride=1920 px0=ff 00 ff ff
da-probe: wrote /tmp/gsr-da-probe.ppm
```

`/tmp/gsr-da-probe.ppm` is 480×64: 29660 magenta, 944 white (the handle circle), 116 edge pixels. Same numbers on the second emission (`queue_repaint`). The client log in that run still says `drawing-area-smoke: client repaint surface=0x0`, and `get_surface_size` still asserts `priv->in_repaint`.

The bytes stick only when they are painted inside that emission. The shell's `vfunc_repaint` runs later, on the private client surface. The proposal at the top is that sync hook plus the memfd copy.

2026-10-08 09:34. Read the nested hold the panel screenshot came from. Did not start a second Weston: that hold is `scripts/nested-weston-hold.sh` on `wayland-gsr` / `wayland-mutter-gsr` and both processes append the same two debug logs.

`org.gnome.ShellRpc.debug.log` at 09:34:23.873 during an allocate invoke:

```text
notification method=repaint
id=5980 method=St-DrawingArea.get_surface_size
id=5981 method=St-DrawingArea.get_surface_size
```

`mutter-rpc.debug.log` on those two calls:

```text
st_drawing_area_get_surface_size: assertion 'priv->in_repaint' failed
```

No `Gsr-St-DrawingArea.paint` in that log. `watch_repaint` had already replied (first one id 559, five in total). A later restart of the same hold (09:37, new connection) logs the same assertion again after `watch_repaint`. `src/` was not changed in this step.

2026-10-08 10:25. Private smoke `bash /tmp/gsr-da-smoke-run.sh` after the preferred-size peer was compiled. Client: `drawing-area-smoke: on stage size=480x64`, then `drawing-area-smoke: miss no-repaint`. Server: preferred width 480, preferred height 64, `queue_repaint`, no `paint`. `Clutter-Actor.add_child` of the drawing area: `invalid (NULL) pointer instance`.

2026-10-08 10:42. User looked at quick settings. The volume row is still a blank space. Recorded as not fixed. No further work.
