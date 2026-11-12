/**
 * Desktop Icons on mutter 18 launches with
 * Meta.WaylandClient.new_subprocess, then sets the client after
 * that call returns. A window that maps during the call is not
 * claimed, the 3s timer kills the process, and a second desktop
 * is launched.
 *
 * Run on the Ubuntu 26.04 VM (mutter 18), not the mutter 16 nest:
 *
 *   GI_META_SMOKE=ding-new-subprocess \
 *     ./build/src/server/gsr-server --debug --wayland
 *
 * Pass: `ding-new-subprocess: ok`
 * Fail: `ding-new-subprocess: miss …`
 */

imports.gi.versions.Meta = '18';
imports.gi.versions.Shell = '18';

const { Gio, GLib, Meta, Shell } = imports.gi;

const SMOKE = 'ding-new-subprocess';
const CLIENT = '/home/alan/gitlive/gnome-shell-rpc/tests/gjs-embed/ding-window-client.js';
const WAIT_MS = 6000;

function smokeLog(message) {
	const line = SMOKE + ': ' + message;
	log(line);
	try {
		const file = Gio.File.new_for_path('/tmp/' + SMOKE + '.log');
		const stream = file.append_to(Gio.FileCreateFlags.NONE, null);
		stream.write_all(line + '\n', null);
		stream.close(null);
	} catch (e) {
	}
}

function titleOf(window) {
	if (window == null)
		return '';
	try {
		if (typeof window.get_title === 'function')
			return window.get_title() ?? '';
		return window.title ?? '';
	} catch (e) {
		return 'title-err';
	}
}

function ownsOf(client, window) {
	try {
		return String(client.owns_window(window));
	} catch (e) {
		return 'err ' + (e != null && e.message != null ? e.message : e);
	}
}

function main() {
	const globalObj = Shell.Global.get();
	const wm = globalObj.window_manager;
	if (wm == null) {
		smokeLog('miss window_manager-null');
		return;
	}

	let client = null;
	let spawnReturned = false;
	let mapsBefore = 0;
	let mapsAfter = 0;
	let ownedAfter = 0;

	wm.connect('map', (_wm, actor) => {
		const window = actor.meta_window ?? actor.get_meta_window?.() ?? null;
		const title = titleOf(window);
		smokeLog('map title=' + title + ' spawnReturned=' + spawnReturned);
		if (!spawnReturned)
			mapsBefore++;
		else
			mapsAfter++;
		if (client == null || window == null)
			return;
		const owns = ownsOf(client, window);
		smokeLog('owns title=' + title + ' owns=' + owns);
		if (owns === 'true' && spawnReturned)
			ownedAfter++;
	});

	const launcher = new Gio.SubprocessLauncher({
		flags: Gio.SubprocessFlags.STDOUT_PIPE
			| Gio.SubprocessFlags.STDERR_MERGE,
	});
	launcher.set_cwd(GLib.get_home_dir());
	let proc = null;
	try {
		client = Meta.WaylandClient.new_subprocess(
			globalObj.context, launcher, ['gjs', CLIENT]);
		proc = client.get_subprocess();
	} catch (e) {
		smokeLog('miss launch ' + (e != null && e.message != null ? e.message : e));
		return;
	}
	spawnReturned = true;
	let exited = 'unset';
	try {
		exited = String(proc.get_if_exited());
	} catch (e) {
		exited = 'err ' + (e != null && e.message != null ? e.message : e);
	}
	smokeLog('spawn-returned mapsBefore=' + mapsBefore + ' exited=' + exited);

	const display = globalObj.get_display();
	const existing = display.list_all_windows?.() ?? [];
	const list = existing != null ? existing : [];
	smokeLog('windows-now=' + list.length);
	for (let i = 0; i < list.length; i++) {
		smokeLog('existing title=' + titleOf(list[i])
			+ ' owns=' + ownsOf(client, list[i]));
	}

	let listed = 0;
	let withActor = 0;
	let withoutActor = 0;
	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	const ctx = GLib.MainContext.default();
	while (GLib.get_monotonic_time() < deadline) {
		while (ctx.pending())
			ctx.iteration(false);
		const now = display.list_all_windows?.() ?? [];
		const n = now != null ? now.length : 0;
		listed = n;
		withActor = 0;
		withoutActor = 0;
		for (let i = 0; i < n; i++) {
			let actor = 'err';
			try {
				actor = String(now[i].get_compositor_private?.() != null);
			} catch (e) {
				actor = 'err';
			}
			if (actor === 'true')
				withActor++;
			else
				withoutActor++;
		}
		if (withActor > 0)
			break;
		GLib.usleep(200 * 1000);
	}

	smokeLog('mapsBefore=' + mapsBefore + ' mapsAfter=' + mapsAfter
		+ ' ownedAfter=' + ownedAfter
		+ ' listed=' + listed
		+ ' withActor=' + withActor
		+ ' withoutActor=' + withoutActor);
	if (listed > 0 && withActor < 1)
		smokeLog('miss no-actor');
	else if (ownedAfter < 1 && withActor < 1)
		smokeLog('miss no-owned-window');
	else
		smokeLog('ok');
	try {
		proc.force_exit();
	} catch (e) {
	}
	try {
		globalObj.context.terminate();
	} catch (e) {
		smokeLog('terminate ' + (e != null && e.message != null ? e.message : e));
	}
}

main();
