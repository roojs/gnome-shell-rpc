/**
 * 0.5.7 C1 — SoundPlayer play + cancel (nested mutter only).
 *
 * Mirrors volume.js: play_from_file with a Gio.Cancellable, then cancel.
 * Optional second play without cancel so a click may be audible.
 *
 * Requires: running gnome-shell-rpc compositor. Our Meta-16 first, then
 * mutter’s typelib dir (Clutter-16 lives there, not in ./build/src).
 *
 *   MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
 *   GI_TYPELIB_PATH=./build/src:$MUTTER_TL${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH} \
 *     ./build/src/gjs-embed --debug src/gjs-embed/sound-smoke.js
 *
 * Override sound file: GI_SOUND_SMOKE_FILE=/path/to.oga
 */

imports.gi.versions.Meta = '16';

const { Gio, GLib, Meta } = imports.gi;

const SMOKE_DOMAIN = 'sound-smoke';
const SOUND_PATH =
	GLib.getenv('GI_SOUND_SMOKE_FILE') ||
	'/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {number} ms
 */
function sleepMs(ms) {
	GLib.usleep(ms * 1000);
}

function main() {
	smokeLog('get_sound_player → play_from_file → cancel');

	const file = Gio.File.new_for_path(SOUND_PATH);
	if (!file.query_exists(null)) {
		throw new Error('sound file missing: ' + SOUND_PATH);
	}

	const display = Meta.get_display();
	const player = display.get_sound_player();
	smokeLog('player lease ok path=' + SOUND_PATH);

	const cancel = new Gio.Cancellable();
	player.play_from_file(file, 'Volume changed', cancel);
	smokeLog('play_from_file (with cancellable) ok');
	sleepMs(50);
	cancel.cancel();
	smokeLog('cancel ok');

	player.play_from_file(file, 'Volume changed', null);
	smokeLog('play_from_file (no cancel) ok');
}

main();
