/**
 * Path ends in ui/init.js so gsr-smoke takes Server-Bootstrap.begin_shell_startup
 * before the shell starts. Without that lock, layout allocates a -12 height
 * and mutter aborts before the menu can be clicked.
 *
 *   GI_META_SMOKE=volume-popup-hide/ui/init ./scripts/weston-gsr-prove.sh
 */
import '../../volume-popup-hide.js';
