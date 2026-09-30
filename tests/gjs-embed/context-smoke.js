/**
 * Minimal Phase 5 probe: Meta.get_display().get_context().
 */
imports.gi.versions.Meta = '16';
const { Meta, GLib } = imports.gi;

log('context-smoke: get_display');
const display = Meta.get_display();
log('context-smoke: display ok');
try {
	const ctx = display.get_context();
	log('context-smoke: context ok type=' + ctx);
} catch (e) {
	log('context-smoke: get_context FAILED: ' + e);
	throw e;
}
log('context-smoke: done');
