/**
 * Path ends in ui/init.js so gsr-smoke takes Server-Bootstrap.begin_shell_startup
 * before the shell starts. Without that lock, layout allocates a -12 height
 * and mutter aborts before either list can be measured.
 *
 *   GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh
 */
import '../../menu-expander-placement.js';
