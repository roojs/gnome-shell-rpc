/**
 * 0.8 Phase B1 register + B2 fire — Display.add_keybinding handler runs
 * after virtual Super+n (schema default for focus-active-notification).
 *
 *   GI_META_SMOKE=key-smoke GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * Host already called Shell.Global.bind_display before this script runs.
 * Event / KeyBinding packing on the notify path is still soft (null args).
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.Clutter = '16';

const { Gio, GLib, Meta, Shell, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'key-smoke';
const SCHEMA = 'org.gnome.shell.keybindings';
const KEY = 'focus-active-notification';
const FIRE_WAIT_MS = 2000;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function main() {
	const globalObj = Shell.Global.get();
	const display = globalObj.display;
	const settings = new Gio.Settings({ schema_id: SCHEMA });
	let fired = false;
	const action = display.add_keybinding(
		KEY, settings, Meta.KeyBindingFlags.NONE, () => {
			fired = true;
			smokeLog('add_keybinding fired');
		});
	smokeLog('add_keybinding action=' + action);
	if (action === 0) {
		throw new Error('key-smoke: add_keybinding returned NONE');
	}
	const custom = Meta.keybindings_set_custom_handler(
		'switch-applications', () => {
			smokeLog('custom handler fired');
		});
	smokeLog('keybindings_set_custom_handler=' + custom);
	if (!custom) {
		throw new Error('key-smoke: keybindings_set_custom_handler returned false');
	}

	smokeLog('fire_key Super+n');
	globalObj.fire_key(Clutter.KEY_n, Clutter.ModifierType.SUPER_MASK);

	const loop = new GLib.MainLoop(null, false);
	const deadline = GLib.get_monotonic_time()
		+ FIRE_WAIT_MS * GLib.TIME_SPAN_MILLISECOND;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
		if (fired || GLib.get_monotonic_time() >= deadline) {
			loop.quit();
			return GLib.SOURCE_REMOVE;
		}
		return GLib.SOURCE_CONTINUE;
	});
	loop.run();

	if (!fired) {
		throw new Error('key-smoke: add_keybinding handler did not fire');
	}
	smokeLog('ok');
}

main();
