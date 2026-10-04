import Meta from 'gi://Meta';
import {RunDialog} from 'resource:///org/gnome/shell/ui/runDialog.js';

RunDialog.prototype._restart = function () {
    this._shouldFadeOut = false;
    this.close();
    Meta.restart(_('Restarting…'), global.context);
};
