/**
 * Path ends in ui/init.js so gsr-smoke takes the shell startup lock
 * before desktop-cube is enabled.
 *
 *   GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=desktop-cube-lockup/ui/init \
 *     ./scripts/agent-nested-smoke-prove.sh
 */
import '../../desktop-cube-lockup-smoke.js';
