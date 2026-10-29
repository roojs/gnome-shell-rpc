/**
 * Path ends in ui/init.js so gsr-smoke takes the shell startup lock
 * before this module runs.
 *
 *   GSR_NESTED_TIMEOUT=40 \
 *     GI_META_SMOKE=startup-overview-sequence/ui/init \
 *     ./scripts/weston-gsr-prove.sh
 */
import '../../startup-overview-sequence.js';
