/**
 * Boot through the product startup lock, then run the applications picker smoke.
 *
 * gsr-smoke calls Server-Bootstrap.begin_shell_startup only when the script
 * path ends in ui/init.js. That is the same lock gsr-client takes before
 * ui/init.js. A smoke that calls main.start() without it allocates the empty
 * Quick Settings grid and mutter aborts on a minimum height of -12, so the
 * picker is never reached.
 *
 *   GI_META_SMOKE=shell-boot/ui/init GSR_WESTON_PIXMAN=1 \
 *     GSR_WESTON_SOCKET=wayland-gsr-apppick \
 *     GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-apppick \
 *     GSR_NESTED_TIMEOUT=90 ./scripts/agent-nested-smoke-prove.sh
 */
import '../../applications-picker-smoke.js';
