/**
 * Panel cube swipe stays off while ClickGesture.enabled is false locally
 * and get_enabled() is still true. This checks that split, then a direct
 * set_enabled(false).
 *
 * Pass: click-enabled: ok
 * Fail: click-enabled: miss
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
imports.gi.versions.Clutter = imports.gi.versions.Meta;
imports.gi.versions.Shell = imports.gi.versions.Meta;

const { GLib, GObject, Clutter, Shell } = imports.gi;

function note(message) {
	const line = 'click-enabled: ' + message;
	console.log(line);
	let prev = '';
	try {
		prev = imports.byteArray.toString(
			GLib.file_get_contents('/tmp/click-enabled-result.txt')[1]);
	} catch (e) {
		prev = '';
	}
	GLib.file_set_contents('/tmp/click-enabled-result.txt', prev + line + '\n');
}

function main() {
	note('begin');
	const cg = new Clutter.ClickGesture();
	const proto = Object.getPrototypeOf(cg);
	const desc = Object.getOwnPropertyDescriptor(proto, 'enabled');
	note('before local=' + cg.enabled
		+ ' desc=' + (desc == null ? 'none' : typeof desc.get)
		+ ' recognize=' + cg.recognize_on_press
		+ ' name=' + cg.name
		+ ' server=' + cg.get_enabled());
	cg.enabled = false;
	note('own=' + Object.prototype.hasOwnProperty.call(cg, 'enabled'));
	const constructed = new Clutter.ClickGesture({
		enabled: false,
		recognize_on_press: true,
	});
	note('ctor server=' + constructed.get_enabled()
		+ ' recognize=' + constructed.recognize_on_press);
	const stage = Shell.Global.get().stage;
	const src = new Clutter.Actor();
	const bound = new Clutter.ClickGesture();
	const binding = src.bind_property(
		'mapped', bound, 'enabled', GObject.BindingFlags.SYNC_CREATE);
	const afterInit = bound.get_enabled();
	stage.add_child(src);
	const afterMap = bound.get_enabled();
	src.hide();
	const afterHide = bound.get_enabled();
	note('bind hasBinding=' + (binding != null)
		+ ' afterInit=' + afterInit
		+ ' afterMap=' + afterMap
		+ ' afterHide=' + afterHide);
	binding?.unbind();
	src.destroy();
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		const server = cg.get_enabled();
		note('property local=' + cg.enabled + ' server=' + server);
		if (cg.enabled === false && server === false
			&& constructed.get_enabled() === false
			&& constructed.recognize_on_press === true
			&& binding != null
			&& afterInit === false
			&& afterMap === true
			&& afterHide === false) {
			note('ok');
		} else {
			cg.set_enabled(false);
			note('direct server=' + cg.get_enabled());
			note('miss');
		}
		loop.quit();
		Shell.Global.get().context.terminate();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
