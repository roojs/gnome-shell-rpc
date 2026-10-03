/* Stock GNOME Shell side of tests/shell-js-probe/dash-icons. Log only.
 * Same lines as the gsr probe, prefix gsr-dash-icons:
 * Enabled by the gsr-dash-probe session mode in ../../modes.
 */
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

function probeLog(msg) {
    console.log(`gsr-dash-icons: ${msg}`);
}

function size(actor) {
    if (!actor)
        return 'null';
    const [minW, natW] = actor.get_preferred_width(-1);
    const [minH, natH] = actor.get_preferred_height(-1);
    const box = actor.get_allocation_box();
    return `pref=${minW}/${natW}x${minH}/${natH} alloc=${box.x1},${box.y1} ${box.get_width()}x${box.get_height()}`;
}

function adjustInputs(dash) {
    const kids = dash._box.get_children().filter(a =>
        a.child && a.child._delegate && a.child._delegate.icon && !a.animatingOut);
    kids.push(dash._showAppsIcon);
    const firstButton = kids[0].child;
    const firstIcon = firstButton._delegate.icon;
    firstIcon.icon.ensure_style();
    const [, , iconW, iconH] = firstIcon.icon.get_preferred_size();
    const [, , buttonW, buttonH] = firstButton.get_preferred_size();
    const themeNode = dash.get_theme_node();
    const bgPad = dash._background.get_theme_node().get_vertical_padding();
    const pad = themeNode.get_vertical_padding();
    const spacing = themeNode.get_length('spacing');
    const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
    const availH = dash._maxHeight - dash.margin_top - dash.margin_bottom -
        bgPad - pad - (buttonH - iconH);
    probeLog(`inputs-now max=${dash._maxWidth}x${dash._maxHeight} n=${kids.length} ` +
        `first=${firstButton.constructor.name} icon=${iconW}x${iconH} button=${buttonW}x${buttonH} ` +
        `margin=${dash.margin_top}/${dash.margin_bottom} bgPad=${bgPad} pad=${pad} spacing=${spacing} ` +
        `scale=${scale} availH=${availH} iconSize=${dash.iconSize}`);
}

function dumpSizes(dash, n) {
    probeLog(`dump#${n} dash ${size(dash)} iconSize=${dash.iconSize} max=${dash._maxWidth}x${dash._maxHeight}`);
    probeLog(`  background ${size(dash._background)}`);
    const sizer = dash._background.get_first_child();
    probeLog(`  sizer ${size(sizer)} constraints=${sizer.get_constraints().length}`);
    for (const c of sizer.get_constraints())
        probeLog(`    bind coord=${c.coordinate} offset=${c.offset} source=${c.source === dash._showAppsIcon.icon ? 'showApps.BaseIcon' : c.source?.constructor?.name}`);
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
}

async function expandSteps() {
    const IconGrid = await import('resource:///org/gnome/shell/ui/iconGrid.js');
    const Dash = await import('resource:///org/gnome/shell/ui/dash.js');
    const Shell = (await import('gi://Shell')).default;
    const V = 1;

    const bin = new Shell.SquareBin();
    const box = new St.BoxLayout({y_expand: true});
    bin.set_child(box);
    probeLog(`step plain squarebin+box needs=${bin.needs_expand(V)}`);

    const base = new IconGrid.BaseIcon('x', {showLabel: false, setSizeManually: true});
    probeLog(`step new BaseIcon needs=${base.needs_expand(V)} box=${base._box.needs_expand(V)}`);

    const app = Shell.AppSystem.get_default().get_running()[0] ??
        Shell.AppSystem.get_default().lookup_app('org.gnome.Settings.desktop') ??
        Shell.AppSystem.get_default().get_installed().map(i => Shell.AppSystem.get_default().lookup_app(i.get_id())).find(a => a);
    const di = new Dash.DashIcon(app);
    probeLog(`step new DashIcon icon.needs=${di.icon.needs_expand(V)} box=${di.icon._box.needs_expand(V)} y_expand_prop=${di.icon.y_expand}`);
}

export default class DashIconProbe extends Extension {
    enable() {
        expandSteps().catch(e => probeLog(`steps err ${e}\n${e.stack}`));
        const dash = Main.overview._overview._controls.dash;
        const theme = St.ThemeContext.get_for_stage(global.stage).get_theme();
        probeLog(`installed mode=${Main.sessionMode.currentMode} sheet=${theme?.theme_stylesheet?.get_path?.()} stage=${global.stage.width}x${global.stage.height}`);
        let dumps = 0;
        this._shownId = Main.overview.connect('shown', () => {
            adjustInputs(dash);
            dumpSizes(dash, ++dumps);
        });
        if (Main.overview.visible && !Main.overview.animationInProgress) {
            adjustInputs(dash);
            dumpSizes(dash, ++dumps);
        } else if (!Main.overview.visible) {
            Main.overview.show();
        }
    }

    disable() {
        Main.overview.disconnect(this._shownId);
    }
}
