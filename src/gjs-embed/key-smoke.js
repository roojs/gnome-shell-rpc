/**
 * 0.5.6 B1 — Display.add_keybinding + keybindings_set_custom_handler
 * (nested mutter only).
 *
 *   GI_META_SMOKE_KEY=1 dbus-run-session ./build/src/gnome-shell-rpc --debug --wayland --nested
 *
 * Registers a shell-schema keybinding. Fire is not required — Clutter.Event
 * packing is still 0.5.3. The callback path is the same Live.Invoke as B2.
 */

imports.gi.versions.Meta = '16';

const { Gio, GLib, Meta } = imports.gi;

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
	const display = Meta.get_display();
	const settings = new Gio.Settings({ schema_id: SCHEMA });
	let bound = false;
	const action = display.add_keybinding(
		KEY, settings, Meta.KeyBindingFlags.NONE, () => {
			bound = true;
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
	smokeLog('ok');
}

main();
