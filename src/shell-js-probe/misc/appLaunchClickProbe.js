/**
 * Debug-only: trace overview/dash AppIcon click → Shell.App activate → launch.
 * Enable with GI_RPC_JS_OVERRIDE_DIR=src/shell-js-probe (see bug
 * 2026-09-22-search-result-click-no-launch.md). Logs use prefix gsr-launch:
 */

import Shell from 'gi://Shell';

let installed = false;

function patchAppIconClass(AppIcon) {
	if (AppIcon == null || AppIcon.prototype.__gsrLaunchProbe)
		return;
	AppIcon.prototype.__gsrLaunchProbe = true;

	const iconProto = AppIcon.prototype;

	if (typeof iconProto.vfunc_clicked === 'function') {
		const origClicked = iconProto.vfunc_clicked;
		iconProto.vfunc_clicked = function () {
			log(`gsr-launch: AppIcon.vfunc_clicked id=${this.app?.get_id?.()} state=${this.app?.state}`);
			return origClicked.call(this);
		};
	}

	const origIconActivate = iconProto.activate;
	iconProto.activate = function () {
		log(`gsr-launch: AppIcon.activate id=${this.app?.get_id()} state=${this.app?.state}`);
		return origIconActivate.call(this);
	};
}

/**
 * Patch Shell.App + AppIcon once (idempotent).
 */
export function installAppLaunchClickProbe() {
	if (installed)
		return;
	installed = true;

	const appProto = Shell.App.prototype;

	const origActivate = appProto.activate;
	appProto.activate = function () {
		log(`gsr-launch: Shell.App.activate id=${this.get_id()} state=${this.state}`);
		return origActivate.call(this);
	};

	const origActivateFull = appProto.activate_full;
	appProto.activate_full = function (workspace, timestamp) {
		log(`gsr-launch: Shell.App.activate_full id=${this.get_id()} state=${this.state} ws=${workspace} ts=${timestamp}`);
		return origActivateFull.call(this, workspace, timestamp);
	};

	if (typeof appProto.launch === 'function') {
		const origLaunch = appProto.launch;
		appProto.launch = function (timestamp, workspace, gpuPref) {
			const path = this.app_info?.get_filename?.() ?? '(no app_info)';
			log(`gsr-launch: Shell.App.launch id=${this.get_id()} path=${path} ts=${timestamp} ws=${workspace}`);
			try {
				const ok = origLaunch.call(this, timestamp, workspace, gpuPref);
				log(`gsr-launch: Shell.App.launch returned ${ok}`);
				return ok;
			} catch (e) {
				log(`gsr-launch: Shell.App.launch threw ${e}`);
				throw e;
			}
		};
	}

	const tryPaths = [
		'resource:///org/gnome/shell/ui/appIcon.js',
		'resource:///org/gnome/shell/ui/appDisplay.js',
	];
	(async () => {
		for (const uri of tryPaths) {
			try {
				const mod = await import(uri);
				if (mod.AppIcon) {
					patchAppIconClass(mod.AppIcon);
					log(`gsr-launch: AppIcon patched via ${uri}`);
					break;
				}
			} catch (e) {
				log(`gsr-launch: skip ${uri}: ${e}`);
			}
		}
	})();

	log('gsr-launch: click/launch probe installed');
}
