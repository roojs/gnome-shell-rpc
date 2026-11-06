/**
 * Path ends in ui/init.js so gsr-smoke takes the shell startup lock
 * before the search runs.
 *
 *   GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=fade-margins-search/ui/init \
 *     ./scripts/agent-nested-smoke-prove.sh
 */
import '../../fade-margins-search-smoke.js';
