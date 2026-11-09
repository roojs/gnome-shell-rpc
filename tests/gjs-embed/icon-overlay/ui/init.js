/**
 * Path ends in ui/init.js so gsr-smoke takes the shell startup lock.
 *
 *   GSR_NESTED_TIMEOUT=80 GI_META_SMOKE=icon-overlay/ui/init \
 *     ./scripts/agent-nested-smoke-prove.sh
 */
import '../../icon-overlay-smoke.js';
