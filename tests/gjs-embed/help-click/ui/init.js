/**
 * Path ends in ui/init.js so gsr-smoke takes Server-Bootstrap.begin_shell_startup
 * before the shell starts. Without that lock, layout allocates a -12 height
 * and mutter aborts before the dash exists.
 *
 *   GI_META_SMOKE=help-click/ui/init ./scripts/agent-nested-smoke-prove.sh
 */
import '../../help-click-smoke.js';
