/**
 * Minimal repro for padOsd.js registerClass cluster (registrations #46–#49
 * before panel.js heap abort).
 *
 *   GI_META_SMOKE=pad-osd-minimal-smoke \
 *     dbus-run-session ./build/src/mutter-rpc --wayland --nested
 */
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import St from 'gi://St';

import 'resource:///org/gnome/shell/ui/environment.js';

const PadChooser = GObject.registerClass(
class PadChooser extends St.Button {
	_init() {
		super._init({toggle_mode: true});
	}
});

const KeybindingEntry = GObject.registerClass(
class KeybindingEntry extends St.Entry {
	_init() {
		super._init({hint_text: 'test'});
	}
});

const ActionComboBox = GObject.registerClass(
class ActionComboBox extends St.Button {
	_init() {
		super._init({style_class: 'button'});
	}
});

const ActionEditor = GObject.registerClass(
class ActionEditor extends St.Widget {
	_init() {
		super._init({
			layout_manager: new Clutter.BoxLayout(),
		});
	}
});

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		console.log('pad-osd-minimal-smoke: registerClass ok, constructing');
		new PadChooser();
		new KeybindingEntry();
		new ActionComboBox();
		new ActionEditor();
		console.log('pad-osd-minimal-smoke: done');
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('pad-osd-minimal-smoke: will register padOsd cluster');
