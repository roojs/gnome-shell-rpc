/**
 * Chrome workarea pin — GJS LayoutManager.set_container must reach
 * vfunc_set_container (stock clutter_layout_manager_set_container).
 *
 * WorkspaceLayout stores _workarea only in vfunc_set_container. If the
 * client set_container no-ops when rpc_lid==0, preferred/allocate see
 * null workarea → JS ERROR flood + broken overview geom.
 *
 *   GI_META_SMOKE=layout-set-container-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * See docs/bugs/2026-09-16-chrome-panel-menus-overlay.md
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter, Meta } = imports.gi;

const SMOKE_DOMAIN = 'layout-set-container-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {boolean} ok
 * @param {string} label
 * @param {string} [detail]
 */
function assert(ok, label, detail) {
	if (ok) {
		smokeLog('PASS ' + label + (detail ? ' ' + detail : ''));
		return;
	}
	smokeLog('FAIL ' + label + (detail ? ' ' + detail : ''));
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null)
		throw new Error(SMOKE_DOMAIN + ': stage is null');

	/* A — Meta.Workspace.get_work_area_for_monitor returns a usable rect. */
	const wm = globalObj.workspace_manager;
	const ws = wm.get_workspace_by_index(0);
	assert(ws != null, 'A', 'workspace0');
	let area = null;
	try {
		area = ws.get_work_area_for_monitor(0);
	} catch (e) {
		assert(false, 'A', 'threw ' + e);
	}
	assert(area != null, 'A', 'work_area non-null');
	if (area != null) {
		assert(area.width > 0 && area.height > 0, 'A',
			`rect ${area.x},${area.y} ${area.width}x${area.height}`);
	}

	/*
	 * B — assigning layout_manager must call vfunc_set_container (stock
	 * clutter_layout_manager_set_container). Mimics WorkspaceLayout
	 * _syncWorkareaTracking.
	 */
	let setContainerHits = 0;
	let lastContainer = 'unset';
	let workarea = null;

	const WorkareaishLayout = GObject.registerClass(
	class WorkareaishLayout extends Clutter.LayoutManager {
		vfunc_set_container(container) {
			setContainerHits++;
			lastContainer = container;
			if (container) {
				workarea = ws.get_work_area_for_monitor(0);
				smokeLog('vfunc_set_container hit=' + setContainerHits
					+ ' workarea=' + (workarea
						? `${workarea.width}x${workarea.height}`
						: 'null'));
			} else {
				workarea = null;
				smokeLog('vfunc_set_container hit=' + setContainerHits
					+ ' container=null');
			}
		}

		vfunc_get_preferred_width(_container, _forHeight) {
			if (workarea == null)
				throw new Error('workarea null in get_preferred_width');
			return [workarea.width, workarea.width];
		}

		vfunc_get_preferred_height(_container, _forWidth) {
			if (workarea == null)
				throw new Error('workarea null in get_preferred_height');
			return [workarea.height, workarea.height];
		}

		vfunc_allocate(container, box) {
			if (workarea == null)
				throw new Error('workarea null in allocate');
			container.set_allocation(box);
		}
	});

	const actor = new St.Widget({
		name: 'layout-set-container-smoke',
		reactive: true,
	});
	actor.set_size(200, 100);
	stage.add_child(actor);
	actor.show();

	setContainerHits = 0;
	workarea = null;
	const lm = new WorkareaishLayout();
	actor.layout_manager = lm;

	assert(setContainerHits >= 1, 'B',
		`vfunc_set_container hits=${setContainerHits} (stock set_container)`);
	assert(lastContainer === actor, 'B', 'container is the actor');
	assert(workarea != null, 'B', 'workarea set from vfunc_set_container');

	/*
	 * C — preferred/allocate must not throw on null workarea (the chrome
	 * JS ERROR). Drive through Helper LM peer if present.
	 */
	let preferredOk = false;
	try {
		const [minW, natW] = actor.get_preferred_width(-1);
		preferredOk = minW > 0 && natW > 0;
		smokeLog(`preferred_width min=${minW} nat=${natW}`);
	} catch (e) {
		smokeLog('preferred_width threw ' + e);
	}
	assert(preferredOk, 'C', 'preferred_width with workarea');

	let allocateOk = false;
	try {
		const box = new Clutter.ActorBox();
		box.init_rect(0, 0, 200, 100);
		actor.allocate(box);
		allocateOk = true;
		smokeLog('allocate returned');
	} catch (e) {
		smokeLog('allocate threw ' + e);
	}
	assert(allocateOk, 'C', 'allocate with workarea');

	/* D — clear path also hits vfunc_set_container(null). */
	const hitsBeforeClear = setContainerHits;
	actor.layout_manager = null;
	assert(setContainerHits > hitsBeforeClear, 'D',
		`clear hits=${setContainerHits - hitsBeforeClear}`);

	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		smokeLog('done');
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
