/**
 * Path ends in ui/init.js so gsr-smoke takes the shell startup lock
 * before this module runs.
 *
 *   GSR_NESTED_TIMEOUT=45 \
 *     GI_META_SMOKE=lock-screen-unlock-smoke/ui/init \
 *     ./scripts/weston-gsr-prove.sh
 */
import '../../lock-screen-unlock-smoke.js';
