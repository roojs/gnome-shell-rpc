/**
 * Product Shell/St typelib facts for empty overview app search.
 * No Weston. Do not new() leased actors (BlurEffect / St.Icon RPC).
 */

import GObject from 'gi://GObject';
import GIRepository from 'gi://GIRepository?version=2.0';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell?version=16';
import St from 'gi://St?version=16';
import Clutter from 'gi://Clutter?version=16';

const repo = GIRepository.Repository.get_default();
let failed = 0;

function fail(name, detail) {
	printerr(`FAIL ${name}: ${detail}`);
	failed++;
}

function ok(name, detail) {
	print(`${name}: ok${detail ? ' ' + detail : ''}`);
}

function openCheck(name, detail) {
	print(`${name}: open ${detail}`);
}

void Gio;
void GObject;

function ifaceName(typeInfo) {
	const iface = GIRepository.type_info_get_interface(typeInfo);
	if (iface === null) {
		return '';
	}
	const ns = iface.get_namespace ? iface.get_namespace() : '';
	const name = iface.get_name ? iface.get_name() : '';
	return ns ? `${ns}.${name}` : name;
}

const appInfo = repo.find_by_name('Shell', 'App');
if (appInfo === null) {
	fail('H-appinfo-gir', 'Shell.App missing from typelib');
} else {
	const method = GIRepository.object_info_find_method(appInfo, 'get_app_info');
	if (method === null) {
		fail('H-appinfo-gir', 'get_app_info missing');
	} else {
		const ret = ifaceName(GIRepository.callable_info_get_return_type(method));
		if (ret !== 'Gio.DesktopAppInfo') {
			fail('H-appinfo-gir', `get_app_info returns ${ret || '(none)'}`);
		} else {
			ok('H-appinfo-gir-typelib', 'get_app_info Gio.DesktopAppInfo');
		}
	}
}

try {
	if (typeof Shell.AppSystem.search !== 'function') {
		fail('H-search', 'AppSystem.search is not a function');
	} else {
		const groups = Shell.AppSystem.search('f');
		let n = 0;
		let first = '';
		if (groups != null) {
			for (let i = 0; i < groups.length; i++) {
				const g = groups[i];
				if (g == null) {
					continue;
				}
				n += g.length;
				if (first === '' && g.length > 0 && g[0]) {
					first = String(g[0]);
				}
			}
		}
		if (n === 0) {
			fail('H-search', 'search(f) hits=0');
		} else {
			ok('H-search', `hits=${n} first=${JSON.stringify(first)}`);
			try {
				const app = Shell.AppSystem.get_default().lookup_app(first);
				if (app == null) {
					fail('H-appinfo-call', `lookup_app ${first} null`);
				} else {
					const info = app.get_app_info();
					const prop = app.app_info;
					ok(
						'H-appinfo-call',
						`id=${JSON.stringify(app.get_id())} get_app_info=${info != null} app_info=${prop != null}`
					);
				}
			} catch (e) {
				fail('H-appinfo-call', String(e));
			}
		}
	}
} catch (e) {
	fail('H-search', String(e));
}

function ctorKind(obj, label) {
	const t = typeof obj;
	if (t !== 'function') {
		fail('H-blur-ctor', `${label} typeof=${t}`);
		return;
	}
	ok('H-blur-ctor', `${label} function`);
}

ctorKind(Shell.BlurEffect, 'Shell.BlurEffect');
if (Clutter.BlurEffect == null) {
	openCheck('H-blur-ctor', 'Clutter.BlurEffect absent');
} else {
	ctorKind(Clutter.BlurEffect, 'Clutter.BlurEffect');
}

/*
 * Stock GridSearchResults._getMaxDisplayedResults does
 * this.allocation.get_width() before updateSearch's try. GJS resolves
 * .allocation via g_object_class_find_property (not get_allocation_box).
 * Generator skips the GObject property (caller-allocates OUT boxed).
 */
if (!('width' in Clutter.Actor.prototype)) {
	fail('H-allocation', 'control: Clutter.Actor.prototype.width missing');
} else if (!('allocation' in Clutter.Actor.prototype)) {
	fail(
		'H-allocation',
		'GObject property allocation missing; GJS this.allocation is undefined'
	);
} else {
	ok('H-allocation', 'GObject property allocation on prototype');
}

const widget = repo.find_by_name('St', 'Widget');
if (widget === null) {
	fail('H-label-nullable', 'St.Widget missing');
} else {
	const setter = GIRepository.object_info_find_method(widget, 'set_label_actor');
	if (setter === null) {
		fail('H-label-nullable', 'set_label_actor missing');
	} else {
		const nArgs = GIRepository.callable_info_get_n_args(setter);
		let nullable = false;
		let argName = '';
		for (let i = 0; i < nArgs; i++) {
			const arg = GIRepository.callable_info_get_arg(setter, i);
			argName = arg.get_name();
			if (argName === 'label') {
				nullable = GIRepository.arg_info_may_be_null(arg);
				break;
			}
		}
		if (nullable) {
			ok('H-label-nullable', 'label may_be_null');
		} else {
			openCheck(
				'H-label-nullable',
				`arg=${argName || '(none)'} may_be_null=false (stock GIR; C allows NULL)`
			);
		}
	}
}

void St;

if (failed) {
	throw new Error(`app-search-empty-gate: ${failed} FAIL`);
}
print('app-search-empty-gate: ok');
