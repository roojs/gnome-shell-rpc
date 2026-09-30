/**
 * Smoke — St D2.1 / D2.2 / D2.3 / D2.4 (theme, set_data, icon sizes, navigate).
 *
 *   GI_META_SMOKE=st-temp-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';
imports.gi.versions.Gio = '2.0';

const { GLib, Gio, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'st-temp-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function main() {
	const globalObj = Shell.Global.get();
	if (globalObj == null) {
		throw new Error('st-temp-smoke: Global is null');
	}
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error('st-temp-smoke: stage is null');
	}

	/* D2.1 — client-owned custom stylesheets list */
	const theme = new St.Theme({
		application_stylesheet: null,
		theme_stylesheet: null,
		default_stylesheet: Gio.File.new_for_path('/usr/share/gnome-shell/theme/Yaru/gnome-shell.css'),
	});
	const customPath = GLib.build_filenamev([
		GLib.get_tmp_dir(),
		`gsr-st-temp-${GLib.get_monotonic_time()}.css`,
	]);
	GLib.file_set_contents(customPath, '/* gsr st-temp-smoke */\n');
	const customFile = Gio.File.new_for_path(customPath);
	theme.load_stylesheet(customFile);
	const customs = theme.get_custom_stylesheets();
	smokeLog(`customs.length=${customs.length}`);
	if (customs.length < 1) {
		throw new Error('st-temp-smoke: get_custom_stylesheets empty');
	}
	try {
		GLib.unlink(customPath);
	} catch (e) {
	}
	smokeLog('D2.1 ok');

	/* D2.3 — icon sizes via Helper + ai */
	const iconTheme = new St.IconTheme();
	smokeLog('D2.3 calling get_icon_sizes');
	const sizes = iconTheme.get_icon_sizes('folder');
	const len = sizes == null ? -1 : sizes.length;
	smokeLog(`folder sizes len=${len}`);
	if (sizes == null) {
		throw new Error('st-temp-smoke: get_icon_sizes returned null');
	}
	smokeLog('D2.3 ok');

	/* D2.4 — navigate_from_event KEY_PRESS Tab */
	const fm = St.FocusManager.get_for_stage(stage);
	if (fm == null) {
		throw new Error('st-temp-smoke: focus_manager null');
	}
	if (typeof Clutter.Event.from_local !== 'function') {
		throw new Error('st-temp-smoke: Clutter.Event.from_local missing');
	}
	const ev = Clutter.Event.from_local(
		Clutter.EventType.KEY_PRESS,
		0, 0, 0,
		0,
		Clutter.KEY_Tab
	);
	const navigated = fm.navigate_from_event(ev);
	smokeLog(`navigate_from_event Tab → ${navigated}`);
	smokeLog('D2.4 ok');

	/* D2.2 — ImageContent.set_data via Request Live.Buffer */
	let Cogl = null;
	try {
		imports.gi.versions.Cogl = '16';
		Cogl = imports.gi.Cogl;
	} catch (e) {
		smokeLog(`Cogl import: ${e}`);
	}
	const image = St.ImageContent.new_with_preferred_size(1, 1);
	const pixels = new Uint8Array([255, 0, 0, 255]);
	let cogl = null;
	try {
		const backend = Clutter.get_default_backend();
		if (backend && typeof backend.get_cogl_context === 'function') {
			cogl = backend.get_cogl_context();
		}
	} catch (e) {
		smokeLog(`client cogl: ${e}`);
	}
	if (Cogl == null || Cogl.PixelFormat == null) {
		throw new Error('st-temp-smoke: Cogl.PixelFormat missing');
	}
	const uploaded = image.set_data(
		cogl, pixels, Cogl.PixelFormat.RGBA_8888, 1, 1, 4);
	smokeLog(`set_data 1x1 → ${uploaded}`);
	if (!uploaded) {
		throw new Error('st-temp-smoke: ImageContent.set_data failed');
	}
	smokeLog('D2.2 ok');

	smokeLog('ok');
}

main();
