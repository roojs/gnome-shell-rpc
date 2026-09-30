/**
 * Deterministic compositor-side desktop launch probe.
 *
 * The nested harness shadows gtk4-demo with a test wrapper. This script then
 * launches org.gtk.Demo4.desktop through Shell.App.launch(), which crosses the
 * existing Helper-AppLaunch boundary. The wrapper records the real child PID,
 * environment, stderr, and exit status. This script separately identifies a
 * Meta window (mutter) or an X11 window on the parent Weston display.
 *
 *   GI_META_SMOKE=app-launch-boundary-smoke \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'app-launch-boundary-smoke';
const APP_ID = 'org.gtk.Demo4.desktop';
const WAIT_MS = 5000;

function smokeLog(message) {
	log(`${SMOKE}: ${message}`);
}

function delay(ms) {
	return new Promise(resolve => {
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
			resolve();
			return GLib.SOURCE_REMOVE;
		});
	});
}

function readText(path) {
	if (!path)
		return '';
	try {
		const [ok, bytes] = GLib.file_get_contents(path);
		return ok ? new TextDecoder().decode(bytes) : '';
	} catch (e) {
		return `read failed: ${formatError(e)}`;
	}
}

function run(argv) {
	try {
		const proc = Gio.Subprocess.new(
			argv,
			Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
		const [, stdout, stderr] = proc.communicate_utf8(null, null);
		return {
			ok: proc.get_successful(),
			stdout: (stdout || '').trim(),
			stderr: (stderr || '').trim(),
		};
	} catch (e) {
		return {ok: false, stdout: '', stderr: formatError(e)};
	}
}

function normalWindowCount(display) {
	let count = 0;
	for (const window of display.list_all_windows() || []) {
		const type = typeof window.get_window_type === 'function'
			? window.get_window_type()
			: window.window_type;
		if (type === Meta.WindowType.NORMAL)
			count++;
	}
	return count;
}

function valueFromProbe(text, key) {
	const prefix = `${key}=`;
	for (const line of text.split('\n')) {
		if (line.startsWith(prefix))
			return line.substring(prefix.length).trim();
	}
	return '';
}

async function runProbe(main) {
	const probeLog = GLib.getenv('GI_APP_LAUNCH_PROBE_LOG') || '';
	const stderrLog = GLib.getenv('GI_APP_LAUNCH_PROBE_STDERR') || '';
	const windowLog = GLib.getenv('GI_APP_LAUNCH_PROBE_WINDOW_LOG') || '';
	smokeLog(`probe-log=${JSON.stringify(probeLog)}`);
	if (!probeLog)
		throw new Error('nested harness did not configure launch probe');

	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	if (display == null)
		throw new Error('Global.get_display() is null');

	const app = Shell.AppSystem.get_default().lookup_app(APP_ID);
	if (app == null)
		throw new Error(`lookup_app(${APP_ID}) returned null`);

	const baseline = normalWindowCount(display);
	let createdWindows = 0;
	let createdNormal = 0;
	display.connect('window-created', (_display, window) => {
		createdWindows++;
		let type = null;
		try {
			type = typeof window.get_window_type === 'function'
				? window.get_window_type()
				: window.window_type;
			if (type === Meta.WindowType.NORMAL)
				createdNormal++;
		} catch (e) {
			smokeLog(`window-created type threw ${formatError(e)}`);
		}
		smokeLog(`window-created count=${createdWindows} type=${type}`);
	});
	smokeLog(`launch id=${APP_ID} baseline-normal=${baseline}`);
	let launchResult = false;
	try {
		launchResult = app.launch(0, -1, Shell.AppLaunchGpu.APP_PREF);
		smokeLog(`Shell.App.launch returned ${launchResult}`);
	} catch (e) {
		smokeLog(`miss dispatch threw ${formatError(e)}`);
		smokeLog('done');
		global.context.terminate();
		return;
	}

	await delay(WAIT_MS);

	let probe = readText(probeLog);
	const childPid = valueFromProbe(probe, 'child_pid');
	const childAlive = childPid
		? run(['kill', '-0', childPid]).ok
		: false;
	const x11 = childPid
		? run(['xdotool', 'search', '--pid', childPid])
		: {ok: false, stdout: '', stderr: 'no child pid'};
	const appWindows = app.get_n_windows();
	const appState = app.state;
	const mutterWindow = valueFromProbe(
		readText(windowLog), 'mutter_window_created') === '1';

	for (const line of probe.trim().split('\n')) {
		if (line)
			smokeLog(`probe ${line}`);
	}
	const stderr = readText(stderrLog).trim();
	smokeLog(`child-alive=${childAlive} x11-windows=${JSON.stringify(x11.stdout)}`);
	smokeLog(`window-created=${createdWindows} normal=${createdNormal}`
		+ ` app-windows=${appWindows} app-state=${appState}`
		+ ` compositor-window=${mutterWindow}`
		+ ` stderr=${JSON.stringify(stderr)}`);

	let result = '';
	if (!launchResult)
		result = 'miss dispatch returned false';
	else if (!childPid)
		result = 'miss spawn wrapper-not-invoked';
	else if (mutterWindow || createdNormal > 0
			|| appWindows > 0 || appState === Shell.AppState.RUNNING)
		result = 'ok target=mutter';
	else if (createdWindows > 0)
		result = 'miss mutter-window-not-normal';
	else if (x11.ok && x11.stdout)
		result = 'miss target=weston-x11';
	else if (!childAlive)
		result = 'miss child-exited-before-map';
	else
		result = 'miss child-running-unmapped';

	if (childAlive) {
		run(['kill', '-TERM', childPid]);
		await delay(500);
		probe = readText(probeLog);
		const exitStatus = valueFromProbe(probe, 'exit_status');
		smokeLog(`cleanup child=${childPid} exit-status=${JSON.stringify(exitStatus)}`);
	}

	smokeLog(result);
	smokeLog('done');
	global.context.terminate();
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => runProbe(main));
		}).catch(e => {
			smokeLog(`FAIL start ${formatError(e)}`);
			const error = new GLib.Error(
				Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, formatError(e));
			global.context.terminate_with_error(error);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
