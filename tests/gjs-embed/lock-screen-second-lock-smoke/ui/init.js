/**
 *   GSR_WESTON_MODE=prove GSR_WESTON_AUTO_CLOSE=1 GSR_NESTED_TIMEOUT=70 \
 *     GI_META_SMOKE=lock-screen-second-lock-smoke/ui/init \
 *     timeout --foreground -k 2 90 ./scripts/weston-gsr-session.sh
 */
import '../../lock-screen-second-lock-smoke.js';
