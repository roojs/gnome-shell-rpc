/**
 * Preload for stock init.js — installed by gnome-shell-rpc when
 * GI_RPC_REGISTER_CLASS_TRACE is set (see ShellApplication.vala).
 *
 * Observe-only: GI_RPC_APP_SEARCH_OBSERVE=1 skips the class tracer.
 * The tracer dies on duplicate GType names (Source) and blanks the nest.
 */
import GLib from 'gi://GLib';

const observe = GLib.getenv('GI_RPC_APP_SEARCH_OBSERVE');
if (observe && observe !== '0' && observe !== 'false') {
	import('./app-search-observe-preload.js');
} else {
	import('./register-class-trace-hook.js').then(({installRegisterClassTrace}) => {
		installRegisterClassTrace();
		console.log('register-class-trace: hook installed before init.js');
	});
}
