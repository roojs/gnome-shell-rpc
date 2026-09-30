// Prove substituted misc/config.js is reachable from libshell gresource.
import * as Config from 'resource:///org/gnome/shell/misc/config.js';

print(
	`config-smoke: PACKAGE_VERSION=${Config.PACKAGE_VERSION} `
	+ `LIBMUTTER_API_VERSION=${Config.LIBMUTTER_API_VERSION}`
);
print('config-smoke: ok');
