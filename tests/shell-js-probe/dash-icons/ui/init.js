/* Dash icon size probe. Log only. Same behaviour as vendor ui/init.js.
 * GI_RPC_JS_OVERRIDE_DIR=tests/shell-js-probe/dash-icons
 * Logs use prefix gsr-dash-icons:
 */
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import './environment.js';
import {formatError} from '../misc/errorUtils.js';

function probeLog(msg) {
    GLib.log_structured('GNOME Shell', GLib.LogLevelFlags.LEVEL_MESSAGE, {
        'MESSAGE': `gsr-dash-icons: ${msg}`,
    });
}

function size(actor) {
    if (!actor)
        return 'null';
    const [minW, natW] = actor.get_preferred_width(-1);
    const [minH, natH] = actor.get_preferred_height(-1);
    const box = actor.get_allocation_box();
    return `pref=${minW}/${natW}x${minH}/${natH} alloc=${box.x1},${box.y1} ${box.get_width()}x${box.get_height()}`;
}

function installDashProbe(Dash, St) {
    const proto = Dash.Dash.prototype;
    const orig = proto._adjustIconSize;
    proto._adjustIconSize = function () {
        try {
            const kids = this._box.get_children().filter(a =>
                a.child && a.child._delegate && a.child._delegate.icon && !a.animatingOut);
            kids.push(this._showAppsIcon);
            const firstButton = kids[0].child;
            const firstIcon = firstButton._delegate.icon;
            firstIcon.icon.ensure_style();
            const [, , iconW, iconH] = firstIcon.icon.get_preferred_size();
            const [, , buttonW, buttonH] = firstButton.get_preferred_size();
            const themeNode = this.get_theme_node();
            const bgPad = this._background.get_theme_node().get_vertical_padding();
            const pad = themeNode.get_vertical_padding();
            const spacing = themeNode.get_length('spacing');
            const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
            const availH = this._maxHeight - this.margin_top - this.margin_bottom -
                bgPad - pad - (buttonH - iconH);
            probeLog(`adjust max=${this._maxWidth}x${this._maxHeight} n=${kids.length} ` +
                `first=${firstButton.constructor.name} icon=${iconW}x${iconH} button=${buttonW}x${buttonH} ` +
                `margin=${this.margin_top}/${this.margin_bottom} bgPad=${bgPad} pad=${pad} spacing=${spacing} ` +
                `scale=${scale} availH=${availH} old=${this.iconSize} ` +
                `iconSizeProp=${firstIcon.iconSize} stIcon.icon_size=${firstIcon.icon.icon_size}`);
        } catch (e) {
            probeLog(`adjust probe err ${e}`);
        }
        const ret = orig.call(this);
        probeLog(`adjust done iconSize=${this.iconSize}`);
        if (!this.__gsrDumpHooked) {
            this.__gsrDumpHooked = true;
            let dumps = 0;
            import('./main.js').then(Main => {
                const theme = St.ThemeContext.get_for_stage(global.stage).get_theme();
                probeLog(`theme mode=${Main.sessionMode.currentMode} sheet=${theme?.theme_stylesheet?.get_path?.()}`);
                Main.overview.connect('shown', () => dumpSizes(this, ++dumps));
            });
        }
        return ret;
    };

    function dumpSizes(dash, n) {
        try {
            probeLog(`dump#${n} dash ${size(dash)} iconSize=${dash.iconSize} max=${dash._maxWidth}x${dash._maxHeight}`);
            probeLog(`  background ${size(dash._background)}`);
            const sizer = dash._background.get_first_child();
            probeLog(`  sizer ${size(sizer)}`);
            const cw = dash._dashContainer.get_allocation_box().get_width();
            probeLog(`  showApps.BaseIcon height-for-${cw}=${dash._showAppsIcon.icon.get_preferred_height(cw)} width-for-44=${dash._showAppsIcon.icon.get_preferred_width(44)}`);
            probeLog(`  container ${size(dash._dashContainer)}`);
            probeLog(`  showApps ${size(dash._showAppsIcon)}`);
            probeLog(`  showApps.button ${size(dash._showAppsIcon.toggleButton)}`);
            probeLog(`  showApps.BaseIcon ${size(dash._showAppsIcon.icon)}`);
            probeLog(`  showApps.St.Icon ${size(dash._showAppsIcon.icon.icon)} icon_size=${dash._showAppsIcon.icon.icon.icon_size}`);
            const first = dash._box.get_first_child();
            if (first?.child?._delegate?.icon) {
                const icon = first.child._delegate.icon;
                probeLog(`  first item ${size(first)}`);
                probeLog(`  first button ${size(first.child)}`);
                probeLog(`  first BaseIcon ${size(icon)}`);
                probeLog(`  first St.Icon ${size(icon.icon)} icon_size=${icon.icon.icon_size}`);
                probeLog(`  first container ${size(icon.get_parent())} layout=${icon.get_parent().layout_manager?.constructor?.name}`);
                probeLog(`  first BaseIcon expand y=${icon.y_expand} needs=${icon.needs_expand(1)} y_align=${icon.y_align} fixed=${icon.fixed_position_set}`);
                probeLog(`  first BaseIcon._box expand y=${icon._box.y_expand} needs=${icon._box.needs_expand(1)} visible=${icon._box.visible}`);
            }
        } catch (e) {
            probeLog(`dump probe err ${e}`);
        }
    }
    probeLog('installed');
}

// Run the Mutter main loop after
// GJS finishes resolving this module.
imports._promiseNative.setMainLoopHook(() => {
    // Queue starting the shell
    GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
        import('./main.js').then(async main => {
            const Dash = await import('./dash.js');
            const {default: St} = await import('gi://St');
            const {default: Shell} = await import('gi://Shell');
            probeLog('step-begin');
            const bin = new Shell.SquareBin();
            const box = new St.BoxLayout({y_expand: true});
            probeLog('step-add');
            bin.set_child(box);
            probeLog(`step plain squarebin+box needs=${bin.needs_expand(1)} box=${box.needs_expand(1)}`);
            installDashProbe(Dash, St);
            main.start();
        }).catch(e => {
            const error = new GLib.Error(
                Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, formatError(e));
            global.context.terminate_with_error(error);
        });
        return GLib.SOURCE_REMOVE;
    });

    // Run the meta context's main loop
    global.context.run_main_loop();
});
