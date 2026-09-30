/**
 * Pin the hidden Quick Settings actor hierarchy.
 *
 * A wrapper hidden before it is parented must keep its BoxPointer, menu box,
 * and negative-height grid unmapped even when child-added triggers a stacking
 * RPC and before-update is delivered in-flow.
 *
 *   GI_META_SMOKE=quicksettings-hidden-tree-smoke \
 *     GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 */

import Clutter from 'gi://Clutter';
import St from 'gi://St';
import GObject from 'gi://GObject';

import 'resource:///org/gnome/shell/ui/environment.js';

const SMOKE = 'quicksettings-hidden-tree-smoke';
let mappedDuringMeasure = false;

const NegativeGrid = GObject.registerClass(
class NegativeGrid extends St.Widget {
    vfunc_get_preferred_height(_forWidth) {
        mappedDuringMeasure ||= this.is_mapped();
        return [-12, -12];
    }
});

const BoxPointerish = GObject.registerClass(
class BoxPointerish extends St.Widget {
    _init() {
        super._init();
        this.bin = new St.Bin();
        this.add_child(this.bin);
    }

    vfunc_get_preferred_height(_forWidth) {
        mappedDuringMeasure ||= this.is_mapped();
        return [0, 0];
    }
});

/**
 * @param {string} message
 */
function smokeLog(message) {
    log(`${SMOKE}: ${message}`);
}

function main() {
    const wrapper = new St.Widget({
        name: 'qs-hidden-wrapper',
        layout_manager: new Clutter.BinLayout(),
    });
    const boxPointer = new BoxPointerish();
    const box = new St.BoxLayout({name: 'qs-hidden-box'});
    const grid = new NegativeGrid({name: 'qs-hidden-grid'});

    boxPointer.bin.set_child(box);
    box.add_child(grid);
    wrapper.add_child(boxPointer);

    let exposedBeforeHide = false;
    const childAddedId = global.stage.connect('child-added', (_stage, child) => {
        if (child !== wrapper)
            return;

        // Match uiGroup's stacking synchronization during add_child().
        global.stage.get_children();
        global.stage.set_child_above_sibling(wrapper, null);
    });
    const beforeUpdateId = global.stage.connect('before-update', () => {
        exposedBeforeHide ||= wrapper.is_mapped();
    });

    // Establish the hidden invariant before the observable add_child RPC.
    wrapper.hide();
    global.stage.add_child(wrapper);

    global.stage.disconnect(beforeUpdateId);
    global.stage.disconnect(childAddedId);

    const [minimum, natural] = grid.get_preferred_height(-1);

    smokeLog(`wrapper visible=${wrapper.visible} mapped=${wrapper.is_mapped()}`);
    smokeLog(`boxPointer visible=${boxPointer.visible} mapped=${boxPointer.is_mapped()}`);
    smokeLog(`box visible=${box.visible} mapped=${box.is_mapped()}`);
    smokeLog(`grid visible=${grid.visible} mapped=${grid.is_mapped()}`);
    smokeLog(`grid preferred min=${minimum} nat=${natural}`);
    smokeLog(`exposedBeforeHide=${exposedBeforeHide}`);
    smokeLog(`mappedDuringMeasure=${mappedDuringMeasure}`);

    if (exposedBeforeHide || mappedDuringMeasure || wrapper.is_mapped() ||
        boxPointer.is_mapped() || box.is_mapped() || grid.is_mapped()) {
        smokeLog('FAIL hidden-before-add tree was exposed');
        return;
    }

    smokeLog('ok');
}

main();
