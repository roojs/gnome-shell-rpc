/**
 * 0.6 Phase 3 — basic drop-in proof for libmutter-rpc.
 *
 * Loads Meta-16 from GI_TYPELIB_PATH and asserts the typelib's shared-library
 * is libmutter-rpc-16.so (not distro libmutter-16.so.0). No compositor needed.
 *
 *   MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
 *   GI_TYPELIB_PATH=./build/src:$MUTTER_TL \
 *   LD_LIBRARY_PATH=./build/src${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} \
 *     ./build/src/gjs-embed --debug src/gjs-embed/mutter-rpc-load.js
 */

imports.gi.versions.Meta = '16';

const { Meta, GIRepository } = imports.gi;

const SMOKE_DOMAIN = 'mutter-rpc-load';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * Fail loudly if Meta did not resolve to our client library.
 */
function assertMutterRpcSharedLibrary() {
	const repo = GIRepository.Repository.dup_default
		? GIRepository.Repository.dup_default()
		: GIRepository.Repository.get_default();
	const libs = repo.get_shared_library('Meta');
	const text = libs === null || libs === undefined ? '' : '' + libs;
	smokeLog('Meta shared-library=' + text);
	if (text.indexOf('mutter-rpc') < 0) {
		throw new Error(
			'Phase 3: expected Meta shared-library to contain mutter-rpc, got: '
				+ text
		);
	}
	const path = repo.get_typelib_path('Meta');
	smokeLog('Meta typelib-path=' + path);
	if (typeof Meta.get_display !== 'function') {
		throw new Error('Phase 3: Meta.get_display missing on stub');
	}
	smokeLog('Meta.get_display ok');
}

function main() {
	smokeLog('load Meta via libmutter-rpc');
	assertMutterRpcSharedLibrary();
	smokeLog('ok');
}

main();
