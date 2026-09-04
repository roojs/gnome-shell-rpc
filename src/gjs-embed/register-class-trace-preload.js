/**
 * Preload for stock init.js — installed by gnome-shell-rpc when
 * GI_RPC_REGISTER_CLASS_TRACE=1 (see ShellApplication.vala).
 */
import { installRegisterClassTrace } from './register-class-trace-hook.js';

installRegisterClassTrace();
console.log('register-class-trace: hook installed before init.js');
