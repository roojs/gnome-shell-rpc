/**
 * GJS must marshal nested GStrv from GsrSearch.AppSystem.search after
 * vala_gir + inject.sh + g-ir-compiler. ping stays from Vala.
 */

import GsrSearch from 'gi://GsrSearch';

if (GsrSearch.AppSystem.ping() !== 'pong') {
	throw new Error('gstrv-gir-gate: ping=' + GsrSearch.AppSystem.ping());
}

const groups = GsrSearch.AppSystem.search('bar');
if (groups === null || groups === undefined) {
	throw new Error('gstrv-gir-gate: search returned empty');
}
if (groups.length !== 1) {
	throw new Error('gstrv-gir-gate: groups.length=' + groups.length);
}
const ids = groups[0];
if (!ids || ids.length !== 2 || ids[0] !== 'foo.desktop' || ids[1] !== 'bar') {
	throw new Error('gstrv-gir-gate: ids=' + JSON.stringify(ids));
}
print('gstrv-gir-gate: ok');
