/**
 * Preload for init.js hold sessions — GI_RPC_LAUNCH_PROBE=1 +
 * GI_RPC_GJS_EMBED_DIR=src/gjs-embed. Logs gsr-launch: to GNOME Shell-Message.
 */

import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';

const LOG = (msg) => log('gsr-launch: ' + msg);

let installed = false;

function patchAppIconClass(AppIcon) {
	if (AppIcon == null || AppIcon.prototype.__gsrLaunchProbe)
		return;
	AppIcon.prototype.__gsrLaunchProbe = true;

	const iconProto = AppIcon.prototype;

	if (typeof iconProto.vfunc_clicked === 'function') {
		const origClicked = iconProto.vfunc_clicked;
		iconProto.vfunc_clicked = function () {
			LOG(`AppIcon.vfunc_clicked id=${this.app?.get_id?.()} state=${this.app?.state}`);
			return origClicked.call(this);
		};
	}

	const origIconActivate = iconProto.activate;
	iconProto.activate = function () {
		LOG(`AppIcon.activate id=${this.app?.get_id()} state=${this.app?.state}`);
		return origIconActivate.call(this);
	};
}

function patchShellApp() {
	const appProto = Shell.App.prototype;

	const origActivate = appProto.activate;
	appProto.activate = function () {
		LOG(`Shell.App.activate id=${this.get_id()} state=${this.state}`);
		return origActivate.call(this);
	};

	const origActivateFull = appProto.activate_full;
	appProto.activate_full = function (workspace, timestamp) {
		LOG(`Shell.App.activate_full id=${this.get_id()} state=${this.state} ws=${workspace} ts=${timestamp}`);
		return origActivateFull.call(this, workspace, timestamp);
	};
}

function installIconPatch() {
	if (installed)
		return;
	installed = true;
	patchShellApp();

	const tryPaths = [
		'resource:///org/gnome/shell/ui/appDisplay.js',
	];
	(async () => {
		for (const uri of tryPaths) {
			try {
				const mod = await import(uri);
				if (mod.AppIcon) {
					patchAppIconClass(mod.AppIcon);
					LOG(`AppIcon patched via ${uri}`);
					break;
				}
			} catch (e) {
				LOG(`skip ${uri}: ${e}`);
			}
		}
	})();

	LOG('probe hooks installed (preload)');
}

function installStageTapLog() {
	const stage = global.stage;
	if (stage == null || stage.__gsrLaunchTap)
		return;
	stage.__gsrLaunchTap = true;

	stage.connect('captured-event', (_stage, event) => {
		const type = event.type();
		if (type !== Clutter.EventType.BUTTON_PRESS
			&& type !== Clutter.EventType.BUTTON_RELEASE)
			return Clutter.EVENT_PROPAGATE;
		const [ok, x, y] = global.get_current_pointer();
		const btn = event.get_button();
		const pick = ok ? global.stage.get_actor_at_pos(Clutter.PickMode.DEFAULT, x, y) : null;
		const name = pick?.constructor?.name ?? 'null';
		LOG(`stage ${type === Clutter.EventType.BUTTON_PRESS ? 'press' : 'release'} btn=${btn} @ ${x},${y} pick=${name}`);
		return Clutter.EVENT_PROPAGATE;
	});

	LOG('stage captured-event tap log on');
}

GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
	installIconPatch();
	installStageTapLog();
	return GLib.SOURCE_REMOVE;
});
