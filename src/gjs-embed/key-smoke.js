/**
 * 0.8 Phase B1 — Display.add_keybinding + keybindings_set_custom_handler
 * (nested mutter via weston prove).
 *
 *   GI_META_SMOKE=key-smoke GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * Registers a shell-schema keybinding. Fire is B2 — Clutter.Event packing
 * still incomplete. Host already called Shell.Global.bind_display before
 * this script runs (use Global, not Meta.get_display bootstrap).
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { Gio, GLib, Meta, Shell } = imports.gi;

const SMOKE_DOMAIN = 'key-smoke';
const SCHEMA = 'org.gnome.shell.keybindings';
const KEY = 'focus-active-notification';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function main() {
	const display = Shell.Global.get().display;
	const settings = new Gio.Settings({ schema_id: SCHEMA });
	const action = display.add_keybinding(
		KEY, settings, Meta.KeyBindingFlags.NONE, () => {
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
	smokeLog('ok');
}

main();
