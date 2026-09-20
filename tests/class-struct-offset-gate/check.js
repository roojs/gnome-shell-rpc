/**
 * GType class_size must cover GIR vfunc slots GJS uses for vfunc_*.
 */

import GObject from 'gi://GObject';
import GIRepository from 'gi://GIRepository?version=2.0';
import Clutter from 'gi://Clutter?version=16';
import St from 'gi://St?version=16';

const repo = GIRepository.Repository.get_default();

function lastFieldEnd(cs) {
	const n = GIRepository.struct_info_get_n_fields(cs);
	if (n < 2) {
		return null;
	}
	const last = GIRepository.struct_info_get_field(cs, n - 1);
	const name = last.get_name();
	if (name === 'parent_class' || name === 'parent') {
		return null;
	}
	return GIRepository.field_info_get_offset(last) + 8;
}

function lastCallbackEnd(cs) {
	let end = null;
	const n = GIRepository.struct_info_get_n_fields(cs);
	for (let i = 0; i < n; i++) {
		const field = GIRepository.struct_info_get_field(cs, i);
		const typeInfo = GIRepository.field_info_get_type(field);
		if (GIRepository.type_info_get_tag(typeInfo) !== GIRepository.TypeTag.INTERFACE) {
			continue;
		}
		const iface = GIRepository.type_info_get_interface(typeInfo);
		if (iface === null || iface.get_type() !== GIRepository.InfoType.CALLBACK) {
			continue;
		}
		end = GIRepository.field_info_get_offset(field) + 8;
	}
	return end;
}

function fieldOffset(info, name) {
	const cs = GIRepository.object_info_get_class_struct(info);
	const n = GIRepository.struct_info_get_n_fields(cs);
	for (let i = 0; i < n; i++) {
		const field = GIRepository.struct_info_get_field(cs, i);
		if (field.get_name() === name) {
			return GIRepository.field_info_get_offset(field);
		}
	}
	return null;
}

function checkNamespace(ns) {
	let failed = 0;
	let checked = 0;
	const n = repo.get_n_infos(ns);
	for (let i = 0; i < n; i++) {
		const info = repo.get_info(ns, i);
		if (info.get_type() !== GIRepository.InfoType.OBJECT) {
			continue;
		}
		const cs = GIRepository.object_info_get_class_struct(info);
		if (cs === null) {
			continue;
		}
		const implied = lastFieldEnd(cs);
		if (implied === null) {
			continue;
		}
		const gtype = GIRepository.registered_type_info_get_g_type(info);
		const q = GObject.type_query(gtype);
		if (!q.class_size) {
			continue;
		}
		checked++;
		const cbEnd = lastCallbackEnd(cs);
		if (cbEnd !== null && q.class_size < cbEnd) {
			printerr(`FAIL ${ns}.${info.get_name()} GType class_size=${q.class_size} GIR vfunc end=${cbEnd} (missing slots)`);
			failed++;
			continue;
		}
		if (q.class_size > implied) {
			printerr(`FAIL ${ns}.${info.get_name()} GType class_size=${q.class_size} GIR last+8=${implied} (extra virtuals)`);
			failed++;
		}
	}
	return [checked, failed];
}

void Clutter;
void St;

let totalChecked = 0;
let totalFailed = 0;
for (const ns of ['Clutter', 'St']) {
	const [c, f] = checkNamespace(ns);
	totalChecked += c;
	totalFailed += f;
}

const button = repo.find_by_name('St', 'Button');
const widget = repo.find_by_name('St', 'Widget');
const clicked = fieldOffset(button, 'clicked');
const styleChanged = fieldOffset(widget, 'style_changed');
if (clicked === null || styleChanged === null) {
	throw new Error('FAIL: missing clicked or style_changed class field');
}
if (clicked === styleChanged) {
	throw new Error(`FAIL: St.Button.clicked GIR offset ${clicked} is St.Widget.style_changed`);
}
print(`ok checked=${totalChecked} clicked@${clicked} style_changed@${styleChanged}`);
if (totalFailed) {
	throw new Error(`class-struct-offset-gate: ${totalFailed} mismatch(es)`);
}
