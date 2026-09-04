/**
 * GI-RPC bisect overlay for vendor ui/messageList.js.
 *
 * Built when -Dgi_rpc_js_overlay_message_list=exit. Terminates on import,
 * before any GObject.registerClass in the real file runs.
 */
import GLib from 'gi://GLib';

console.log('gi-rpc overlay: messageList.js - exit before registerClass');

const ctx = global.context;
if (ctx != null && typeof ctx.terminate === 'function') {
	ctx.terminate();
} else {
	console.error('gi-rpc overlay: global.context.terminate missing');
}

/** @type {typeof import('./messageList.js').URLHighlighter} */
export const URLHighlighter = class {};

/** @type {typeof import('./messageList.js').Source} */
export const Source = class {};

/** @type {typeof import('./messageList.js').Message} */
export const Message = class {};

/** @type {typeof import('./messageList.js').NotificationMessage} */
export const NotificationMessage = class {};

/** @type {typeof import('./messageList.js').MessageView} */
export const MessageView = class {};
