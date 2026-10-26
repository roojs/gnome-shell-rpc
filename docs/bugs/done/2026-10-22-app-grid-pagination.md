# App grid pages do not change

**Status:** ✅ done. User confirmed closure on 2026-10-26. `St.Viewport` now retains the real `St.ScrollView` adjustments, so `AppGrid` has the horizontal adjustment used by `goToPage()`.

The focused gate passes without its test-only fix arm. The separate early
`Clutter-Actor.allocate` startup disconnect remains outside this bug.

The focused reproduction is `tests/gjs-embed/app-grid-pagination-smoke.js`:

```bash
GSR_WESTON_SOCKET=wayland-gsr-pagegate \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-pagegate \
GI_META_SMOKE=app-grid-pagination-smoke GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=30 ./scripts/agent-nested-smoke-prove.sh
```

It fails:

```text
app-grid-pagination-smoke: adjustments viewport=null/null scroll=set/set
app-grid-pagination-smoke: miss adjustments
```

The same gate with its test-only copy of the proposed behavior passes:

```bash
GSR_PAGE_FIX=1 \
GSR_WESTON_SOCKET=wayland-gsr-pagefix \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-pagefix \
GI_META_SMOKE=app-grid-pagination-smoke GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=30 ./scripts/agent-nested-smoke-prove.sh
```

```text
app-grid-pagination-smoke: adjustments viewport=set/set scroll=set/set
app-grid-pagination-smoke: ok
```

## Applied fix

The test-only pass stores the two real `St.Adjustment` objects on the
viewport and mirrors the containing scroll view's adjustments when attaching
the child. No new API is introduced.

### 1. `src/client/libst-rpc-16/overrides/Viewport.override.vala` — `St.Scrollable` adjustment state

**Why:** `IconGrid.goToPage()` reads the viewport's horizontal adjustment.
The current fieldless implementation always returns null.

**Where:** Replace the fieldless adjustment properties and methods after
`rpc_construct()`.

**Depends on:** none.

#### Remove

```vala
		/* Row 12 bisect: fieldless property stubs. */
		public Adjustment hadjustment {
			get { return null; }
			set { }
		}

		public Adjustment vadjustment {
			get { return null; }
			set { }
		}

		public void get_adjustments(out Adjustment hadjustment, out Adjustment vadjustment)
		{
			hadjustment = null;
			vadjustment = null;
		}

		public void set_adjustments(Adjustment hadjustment, Adjustment vadjustment)
		{
		}
```

#### Replace with

```vala
		private Adjustment client_hadjustment;
		private Adjustment client_vadjustment;

		public Adjustment hadjustment {
			get { return this.client_hadjustment; }
			set { this.client_hadjustment = value; }
		}

		public Adjustment vadjustment {
			get { return this.client_vadjustment; }
			set { this.client_vadjustment = value; }
		}

		public void get_adjustments(out Adjustment hadjustment, out Adjustment vadjustment)
		{
			hadjustment = this.client_hadjustment;
			vadjustment = this.client_vadjustment;
		}

		public void set_adjustments(Adjustment hadjustment, Adjustment vadjustment)
		{
			this.client_hadjustment = hadjustment;
			this.client_vadjustment = vadjustment;
		}
```

### 2. `src/client/libst-rpc-16/overrides/ScrollView.override.vala` — `child` setter adjustment mirror

**Why:** Stock `st_scroll_view_set_child()` gives its adjustments to the
`St.Scrollable` child in the compositor process. The client peer needs the
same real adjustment proxies so shell JavaScript can drive them.

**Where:** In the existing `child` property setter, immediately after the
successful `St-ScrollView.set_child` RPC.

**Depends on:** proposal 1.

#### Remove

```vala
			set {
				Gsr.Client.Rpc.call_value(
					"St-ScrollView.set_child", this,
					OLLMrpc.args("o", value));
			}
```

#### Replace with

```vala
			set {
				Gsr.Client.Rpc.call_value(
					"St-ScrollView.set_child", this,
					OLLMrpc.args("o", value));
				if (value != null) {
					value.set_adjustments(
						this.hadjustment, this.vadjustment);
				}
			}
```

Split from [`2026-10-12-applications-picker-not-working.md`](2026-10-12-applications-picker-not-working.md).

- Performance: [`2026-10-22-app-grid-performance.md`](../2026-10-22-app-grid-performance.md)
- Construct switch: [`2026-10-22-actor-construct-lease-switch.md`](2026-10-22-actor-construct-lease-switch.md)

```bash
GSR_WESTON_SOCKET=wayland-gsr-apppick \
GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-apppick \
GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 \
GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh
```

Read `nested-weston-prove.tee.log`. The autolaunch log is about 5GB.

**Where it stands:** The grid is on screen after the click. The page size has been `800x299` with 147 items. Paging that grid is the failure. Nothing in the smoke changes page.

Existing-log prove (2026-10-26 08:34):

- `~/.cache/gnome-shell-rpc/nested-weston-prove.tee.log`: seven page dots are visible in `applications-picker.png`; page 0 is selected.
- `applications-picker-smoke: state=2 checked=true visible=true mapped=true items=147 page=800x299 pickable=30`
- `applications-picker-smoke: miss overlap`
- `~/.cache/gnome-shell-rpc/weston-autolaunch-prove.log`: `nested-weston-prove: stop (smoke-fail) after 68s`

## LLM efforts

### 2026-10-22 10:15 split from the picker bug

The picker archive is the record of the grid becoming visible. Pagination was not a pass there.

### 2026-10-26 09:00 read existing logs

Read the current client, server, nested prove, and smoke output before changing the reproduction. The 08:34 run reached the application grid with 147 items and seven visible page dots, then failed its pre-existing overlap assertion. It did not attempt a page change, so the reported pagination failure was not yet mechanically proved.

### 2026-10-26 09:21 page-dot reproduction, startup attempts 1–2

Extended `tests/gjs-embed/applications-picker-smoke.js` to click the second page dot through the virtual pointer, then compare `IconGrid.currentPage`, the scroll adjustment, and item 0's transformed position. Two runs of the command above did not reach the click: both lost the RPC connection during an early `Clutter-Actor.allocate`; the stop line was `nested-weston-prove: mutter exited ec=133 after 7s`. The smoke's later `global.stage.context is null` was teardown after the disconnect, not a pagination result.

### 2026-10-26 09:32 page-dot reproduction, startup attempt 3

The third run also lost the RPC connection during early `Clutter-Actor.allocate` and stopped `mutter exited ec=133 after 8s`. It did not reach the app grid.

### 2026-10-26 09:36 focused adjustment gate

Added `tests/gjs-embed/app-grid-pagination-smoke.js`, which creates a real `St.ScrollView` with a GJS `St.Viewport` subclass child, allocates it, and compares the adjustments visible at each end. The command in the top account logged `adjustments viewport=null/null scroll=set/set` and `miss adjustments`.

This matches the stock app-grid path: `vendor/gnome-shell/js/ui/iconGrid.js` `IconGrid.goToPage()` chooses the viewport's `hadjustment` for horizontal grids and calls `adjustment.ease(...)`. The generated client body comes from `src/client/libst-rpc-16/overrides/Viewport.override.vala`, whose fieldless `hadjustment` and `vadjustment` getters return null, whose setters do nothing, and whose `get_adjustments`/`set_adjustments` methods likewise discard the values. The missing implementation is therefore the viewport side of the real `St.Scrollable` adjustment API, not a missing page-dot hook.

### 2026-10-26 09:45 prove the proposed behavior off product code

Added a `GSR_PAGE_FIX=1` arm to the focused smoke. Its local `St.Viewport`
subclass stores both adjustments, and the test mirrors the enclosing
`St.ScrollView` adjustments after attaching the child. Product `src/` stayed
unchanged. The run logged `adjustments viewport=set/set scroll=set/set` and
`app-grid-pagination-smoke: ok`.

### 2026-10-26 09:54 apply and verify

Applied the two reviewed hunks to `Viewport.override.vala` and
`ScrollView.override.vala`. `meson compile -C build` passed. The focused gate
without `GSR_PAGE_FIX` logged `adjustments viewport=set/set scroll=set/set`
and `app-grid-pagination-smoke: ok`.

Two runs of the page-dot smoke after landing stopped before the app grid:
`nested-weston-prove: mutter exited ec=133 after 7s`. Both disconnected during
an early `Clutter-Actor.allocate` and then logged the teardown symptom
`global.stage.context is null`; neither produced a page-navigation result.
