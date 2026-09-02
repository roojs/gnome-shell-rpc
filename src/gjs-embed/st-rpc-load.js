/**
 * 0.7.6 Phase C — St resolves to libst-rpc-16.so and one RPC round-trip works.
 *
 * Manual (no compositor):
 *   MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
 *   GI_TYPELIB_PATH=./build/src:$MUTTER_TL \
 *   LD_LIBRARY_PATH=./build/src \
 *     ./build/src/gjs-embed --debug src/gjs-embed/st-rpc-load.js
 *
 * Nested (compositor spawns gnome-shell-rpc with build typelibs on PATH):
 *   GI_META_SMOKE=st-rpc-load.js \
 *     dbus-run-session ./build/src/mutter-rpc --wayland --nested
 */

imports.gi.versions.St = '16';
imports.gi.versions.Meta = '16';

const { St, Meta, GIRepository } = imports.gi;

const SMOKE_DOMAIN = 'st-rpc-load';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * Fail loudly if St did not resolve to our client library.
 */
function assertStRpcSharedLibrary() {
	const repo = GIRepository.Repository.dup_default
		? GIRepository.Repository.dup_default()
		: GIRepository.Repository.get_default();
	const libs = repo.get_shared_library('St');
	const text = libs === null || libs === undefined ? '' : '' + libs;
	smokeLog('St shared-library=' + text);
	if (text.indexOf('st-rpc') < 0) {
		throw new Error(
			'Phase C: expected St shared-library to contain st-rpc, got: '
				+ text
		);
	}
	const path = repo.get_typelib_path('St');
	smokeLog('St typelib-path=' + path);
}

/**
 * St namespace RPC round-trip (server runs linked libst-16.so).
 */
function assertStRpcRoundTrip() {
	const quark = St.icon_theme_error_quark();
	smokeLog('St.icon_theme_error_quark=' + quark);
	if (typeof quark !== 'number' || quark === 0) {
		throw new Error('Phase C: St.icon_theme_error_quark returned ' + quark);
	}
}

function main() {
	smokeLog('load St via libst-rpc-16');
	assertStRpcSharedLibrary();
	assertStRpcRoundTrip();
	smokeLog('ok');
}

main();
