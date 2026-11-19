/**
 * 0.8 Phase B1 register + B2 fire — Display.add_keybinding handler runs
 * after virtual Super+n (schema default for focus-active-notification).
 *
 *   GI_META_SMOKE=key-smoke GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * Host already called Shell.Global.bind_display before this script runs.
 * Event / KeyBinding packing on the notify path is still soft (null args).
 */

function meta_version() {
	try {
		imports.gi.versions.Meta = '18';
		void imports.gi.Meta;
		return '18';
	} catch (e) {
		imports.gi.versions.Meta = '16';
		return '16';
	}
}
imports.gi.versions.Meta = meta_version();
imports.gi.versions.Shell = imports.gi.versions.Meta;
imports.gi.versions.Clutter = imports.gi.versions.Meta;

const { Gio, GLib, Meta, Shell, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'key-smoke';
const SCHEMA = 'org.gnome.shell.keybindings';
const KEY = 'focus-active-notification';
const SWITCH = 'switch-to-workspace-left';
const FIRE_WAIT_MS = 2000;

/**
 * @param {string} accel
 * @returns {[number, number]}
 */
function accel_key(accel) {
	let mods = 0;
	let key = accel;
	const tokens = {
		'<Control>': Clutter.ModifierType.CONTROL_MASK,
		'<Primary>': Clutter.ModifierType.CONTROL_MASK,
		'<Alt>': Clutter.ModifierType.MOD1_MASK,
		'<Super>': Clutter.ModifierType.SUPER_MASK,
		'<Shift>': Clutter.ModifierType.SHIFT_MASK,
	};
	for (const token in tokens) {
		if (key.includes(token)) {
			mods |= tokens[token];
			key = key.replace(token, '');
		}
	}
	const keys = {
		Left: Clutter.KEY_Left,
		Right: Clutter.KEY_Right,
		Up: Clutter.KEY_Up,
		Down: Clutter.KEY_Down,
		Page_Up: Clutter.KEY_Page_Up,
		Page_Down: Clutter.KEY_Page_Down,
	};
	return [keys[key], mods];
}

/**
 * Same split as windowManager.js _showWorkspaceSwitcher.
 *
 * @param {string} name
 * @returns {string}
 */
function switch_target(name) {
	const parts = name.split('-');
	const target = parts[3];
	return target.toUpperCase();
}

/**
 * @param {string} message
 */
function smokeLog(message) {
	const line = SMOKE_DOMAIN + ': ' + message;
	log(line);
	let prev = '';
	try {
		prev = GLib.file_get_contents('/tmp/key-smoke-result.txt')[1];
	} catch (e) {
		prev = '';
	}
	GLib.file_set_contents('/tmp/key-smoke-result.txt', prev + line + '\n');
}

function main() {
	smokeLog('begin');
	const globalObj = Shell.Global.get();
	const display = globalObj.display;
	const settings = new Gio.Settings({ schema_id: SCHEMA });
	let fired = false;
	let addedName = '';
	const action = display.add_keybinding(
		KEY, settings, Meta.KeyBindingFlags.NONE,
		(_display, _window, _event, binding) => {
			fired = true;
			try {
				addedName = binding.get_name();
			} catch (e) {
				addedName = 'throw:' + e.message;
			}
			smokeLog('add_keybinding fired name=' + addedName);
		});
	smokeLog('add_keybinding action=' + action);
	if (action === 0) {
		throw new Error('key-smoke: add_keybinding returned NONE');
	}
	let customName = '';
	let customDir = '';
	const custom = Meta.keybindings_set_custom_handler(
		SWITCH, (_display, _window, _event, binding) => {
			try {
				customName = binding.get_name();
				customDir = switch_target(customName);
			} catch (e) {
				customName = 'throw:' + e.message;
			}
			smokeLog('custom name=' + customName + ' dir=' + customDir);
		});
	smokeLog('keybindings_set_custom_handler=' + custom);
	if (!custom) {
		throw new Error('key-smoke: keybindings_set_custom_handler returned false');
	}

	smokeLog('fire_key Super+n');
	globalObj.fire_key(Clutter.KEY_n, Clutter.ModifierType.SUPER_MASK);
	smokeLog('after Super+n fired=' + fired + ' name=' + addedName);
	const wm = new Gio.Settings({
		schema_id: 'org.gnome.desktop.wm.keybindings',
	});
	const accel = wm.get_strv(SWITCH)[0];
	const [keyval, mods] = accel_key(accel);
	smokeLog('fire_key ' + accel + ' keyval=' + keyval + ' mods=' + mods);
	if (keyval) {
		globalObj.fire_key(keyval, mods);
	}

	const loop = new GLib.MainLoop(null, false);
	const deadline = GLib.get_monotonic_time()
		+ FIRE_WAIT_MS * GLib.TIME_SPAN_MILLISECOND;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
		if ((fired && customName !== '') || GLib.get_monotonic_time() >= deadline) {
			loop.quit();
			return GLib.SOURCE_REMOVE;
		}
		return GLib.SOURCE_CONTINUE;
	});
	loop.run();

	if (!fired) {
		smokeLog('miss add_keybinding did not fire');
		return;
	}
	if (addedName !== KEY) {
		smokeLog('miss add name=' + addedName);
		return;
	}
	if (customName !== SWITCH || customDir !== 'LEFT') {
		smokeLog('miss custom name=' + customName + ' dir=' + customDir);
		return;
	}
	smokeLog('ok');
}

main();
