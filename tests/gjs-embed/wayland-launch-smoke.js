/**
 * Bare Gio launch inside nested gnome-shell-rpc — pass only if Meta sees a
 * NORMAL client window (not Gio "launch returned true" alone; gtk4-demo on
 * Weston XWayland still fails).
 *
 *   ./scripts/run-wayland-launch-smoke.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { Gio, GLib, Meta, Shell } = imports.gi;

const SMOKE = 'wayland-launch-smoke';
const CMD = GLib.getenv('GI_META_SMOKE_CMD') || 'gtk4-demo';
const WAIT_MS = parseInt(GLib.getenv('GI_META_SMOKE_WAIT_MS') || '4000', 10);

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function listWindows(display) {
	if (typeof display.list_all_windows === 'function') {
		const list = display.list_all_windows();
		return list != null ? list : [];
	}
	const focus = display.get_focus_window();
	return focus != null ? [focus] : [];
}

function procBaseName(cmd) {
	const tok = cmd.trim().split(/\s+/)[0];
	const slash = tok.lastIndexOf('/');
	return slash >= 0 ? tok.substring(slash + 1) : tok;
}

/** Harness: where did the child land? */
function logSpawnProbe(cmd) {
	const base = procBaseName(cmd);
	try {
		const [, out] = GLib.spawn_command_line_sync(
			'pgrep -a ' + base + ' 2>/dev/null || true');
		const text = out ? imports.byteArray.toString(out).trim() : '';
		smokeLog('proc ' + base + '=' + (text || '(none)'));
		if (!text)
			return;
		const pid = text.split(/\s+/)[0];
		const [, envOut] = GLib.spawn_command_line_sync(
			"tr '\\0' '\\n' </proc/" + pid + '/environ | grep -E ' +
			"'^(DISPLAY|WAYLAND_DISPLAY|GDK_BACKEND)=' || true");
		const envText = envOut ? imports.byteArray.toString(envOut).trim() : '';
		if (envText.length === 0) {
			smokeLog('proc-env (none matched for pid ' + pid + ')');
		} else {
			for (const line of envText.split('\n'))
				smokeLog('proc-env ' + line);
		}
	} catch (e) {
		smokeLog('proc probe: ' + e);
	}
}

function windowType(w) {
	if (w == null)
		return null;
	if (typeof w.get_window_type === 'function')
		return w.get_window_type();
	return w.window_type;
}

function countNormalWindows(display) {
	let n = 0;
	const list = listWindows(display);
	for (const w of list) {
		if (w == null)
			continue;
		const t = windowType(w);
		if (t === Meta.WindowType.NORMAL)
			n++;
	}
	return n;
}

function makeLaunchContext(globalObj) {
	const ctx = globalObj.create_app_launch_context(0, -1);
	if (GLib.getenv('GI_WAYLAND_LAUNCH_UNSET_DISPLAY') === '1') {
		ctx.unsetenv('DISPLAY');
		smokeLog('ctx: unset DISPLAY');
	}
	return ctx;
}

function main() {
	const wl = GLib.getenv('WAYLAND_DISPLAY');
	if (wl == null || wl.length === 0) {
		throw new Error('WAYLAND_DISPLAY unset');
	}
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	const baseline = countNormalWindows(display);
	const rt = GLib.getenv('XDG_RUNTIME_DIR');
	smokeLog('WAYLAND_DISPLAY=' + JSON.stringify(wl));
	smokeLog('XDG_RUNTIME_DIR=' + (rt != null ? JSON.stringify(rt) : '(unset)'));
	smokeLog('DISPLAY=' + JSON.stringify(GLib.getenv('DISPLAY')));
	smokeLog('cmd=' + CMD);
	smokeLog('windows-normal baseline=' + baseline);

	smokeLog('path=create_app_launch_context + Gio');
	const ctx = makeLaunchContext(globalObj);

	const app = Gio.AppInfo.create_from_commandline(
		CMD, null, Gio.AppInfoCreateFlags.NONE);
	if (app === null) {
		throw new Error('create_from_commandline failed');
	}
	const ok = app.launch([], ctx);
	smokeLog('launch returned ' + ok);
	if (!ok) {
		throw new Error('Gio.AppInfo.launch returned false');
	}

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	let normal = baseline;
	while (GLib.get_monotonic_time() < deadline) {
		normal = countNormalWindows(display);
		if (normal > baseline) {
			break;
		}
		GLib.usleep(200 * 1000);
	}

	smokeLog('windows-normal after=' + normal);
	if (normal <= baseline) {
		logSpawnProbe(CMD);
		smokeLog('miss — Gio ok but Meta sees no new window (app may be on Weston DISPLAY=' +
			JSON.stringify(GLib.getenv('DISPLAY')) + ', not mutter WL)');
		throw new Error('no Meta NORMAL window after launch');
	}
	smokeLog('ok');
}

main();
