/**
 * Reproduce the split-RPC exposure between stock PanelMenu.setMenu()'s
 * add_child() and hide() calls.
 *
 *   GI_META_SMOKE=quicksettings-add-hide-race-smoke \
 *     GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 */

import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import St from 'gi://St';

import 'resource:///org/gnome/shell/ui/environment.js';

const SMOKE = 'quicksettings-add-hide-race-smoke';
let hideRequested = false;
let exposed = false;

const NegativeGrid = GObject.registerClass(
class NegativeGrid extends St.Widget {
    vfunc_get_preferred_height(_forWidth) {
        return [-12, -12];
    }
});

function smokeLog(message) {
    log(`${SMOKE}: ${message}`);
}

function main() {
    const wrapper = new St.Widget({
        name: 'qs-race-wrapper',
        layout_manager: new Clutter.BinLayout(),
    });
    const boxPointer = new St.Widget({
        name: 'qs-race-box-pointer',
        layout_manager: new Clutter.BinLayout(),
    });
    const box = new St.BoxLayout({name: 'qs-race-box'});
    const grid = new NegativeGrid({name: 'qs-race-grid'});

    box.add_child(grid);
    boxPointer.add_child(box);
    wrapper.add_child(boxPointer);

    const childAddedId = global.stage.connect('child-added', (_stage, child) => {
        if (child !== wrapper)
            return;

        // Match uiGroup's stacking synchronization during add_child().
        global.stage.get_children();
        global.stage.set_child_above_sibling(wrapper, null);
    });
    const beforeUpdateId = global.stage.connect('before-update', () => {
        if (hideRequested || !wrapper.is_mapped())
            return;

        const [minimum, natural] = grid.get_preferred_height(-1);
        exposed = true;
        smokeLog(
            `exposed-before-hide wrapper-mapped=true min=${minimum} nat=${natural}`);
    });

    global.stage.add_child(wrapper);
    hideRequested = true;
    wrapper.hide();

    global.stage.disconnect(beforeUpdateId);
    global.stage.disconnect(childAddedId);

    if (exposed) {
        smokeLog('FAIL add_child dispatched layout before hide');
        return;
    }

    smokeLog('ok');
}

main();
