/**
 * Pin — a SquareBin style-changed that calls super, then sync_hover,
 * must not loop.
 *
 * 2026-10-02 15:09 full-shell crash was 67 frames of
 * BaseIcon.vfunc_style_changed at iconGrid.js:137, under
 * AppIcon.vfunc_leave_event during app-grid addItem. This smoke does
 * not take that path. Nested set_style re-entered once (maxDepth=2)
 * and returned. sync_hover did not enter leave_event (maxDepth=1).
 * It does not name that crash. Do not treat a pass here as the fix.
 *
 *   GI_META_SMOKE=style-reenter-smoke ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, Shell, St } = imports.gi;

const SMOKE_DOMAIN = 'style-reenter-smoke';
const DEPTH_LIMIT = 4;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

const Iconish = GObject.registerClass(
class Iconish extends Shell.SquareBin {
	_init() {
		super._init({ style_class: 'overview-icon' });
		this._bin = new St.Bin();
		this.add_child(this._bin);
		this.iconSize = 0;
		this.entered = 0;
		this.completed = 0;
		this.maxDepth = 0;
		this._depth = 0;
		this._askedNested = false;
		this.leaveEntered = 0;
		this.error = '';
		this.connect('notify::hover', () => {
			void this.hover;
		});
	}

	vfunc_leave_event(event) {
		this.leaveEntered++;
		return super.vfunc_leave_event(event);
	}

	vfunc_style_changed() {
		this.entered++;
		this._depth++;
		if (this._depth > this.maxDepth)
			this.maxDepth = this._depth;
		/* Stop the loop inside super() before it reaches GJS's recursion
		 * limit. Depth above the limit is the failure. */
		if (this._depth > DEPTH_LIMIT) {
			this._depth--;
			return;
		}
		try {
			super.vfunc_style_changed();
			/* The 15:09 crash is a style-changed that arrives while this
			 * vfunc is still on the stack. set_style emits that signal
			 * after its RPC returns. */
			if (!this._askedNested) {
				this._askedNested = true;
				this.sync_hover();
			}
			const size = 32;
			if (!(this.iconSize === size && this._bin.child)) {
				if (this._bin.child)
					this._bin.child.destroy();
				this.iconSize = size;
				this._bin.child = new St.Icon({
					icon_name: 'view-app-grid-symbolic',
					icon_size: size,
				});
			}
			this.completed++;
		} catch (e) {
			this.error = String(e);
		} finally {
			this._depth--;
		}
	}
});

function main() {
	const stage = Shell.Global.get().get_stage();
	if (stage == null) {
		smokeLog('miss stage is null');
		return;
	}

	const icon = new Iconish({ name: 'style-reenter-smoke' });
	stage.add_child(icon);
	icon.set_position(40, 40);
	icon.set_size(48, 48);
	icon.show();
	icon.set_style('padding: 6px;');
	icon.ensure_style();

	smokeLog(`entered=${icon.entered} completed=${icon.completed} ` +
		`maxDepth=${icon.maxDepth} leave=${icon.leaveEntered} ` +
		`child=${icon._bin.child != null} error=${icon.error}`);

	if (icon.error.length > 0 || icon.maxDepth > 2 || icon.completed < 1 ||
			icon._bin.child == null) {
		smokeLog('miss');
		return;
	}
	smokeLog('ok');
}

main();
