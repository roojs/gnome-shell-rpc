import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const CLIENT = '/home/alan/gitlive/gnome-shell-rpc/tests/gjs-embed/ding-window-client.js';
const LOG = '/tmp/actor-probe.log';

function note(message) {
    try {
        const file = Gio.File.new_for_path(LOG);
        const stream = file.append_to(Gio.FileCreateFlags.NONE, null);
        stream.write_all(message + '\n', null);
        stream.close(null);
    } catch (e) {
        console.log(`actor-probe write ${e}`);
    }
}

export default class ActorProbe extends Extension {
    enable() {
        note('enable');
        const launcher = new Gio.SubprocessLauncher({ flags: Gio.SubprocessFlags.NONE });
        let client = null;
        try {
            client = Meta.WaylandClient.new_subprocess(global.context, launcher, ['gjs', CLIENT]);
        } catch (e) {
            note(`launch ${e}`);
            return;
        }
        note('spawned');
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
            try {
                const wins = global.display.list_all_windows();
                const parts = [];
                for (const w of wins) {
                    let actor = 'err';
                    try {
                        actor = String(w.get_compositor_private() != null);
                    } catch (e) {
                        actor = `err ${e}`;
                    }
                    parts.push(`${w.get_title()} actor=${actor}`);
                }
                note(`t2 n=${wins.length} ${parts.join(' | ')}`);
                const bare = parts.filter(p => p.startsWith('Probe Window') && p.includes('actor=false'));
                const mapped = parts.filter(p => p.startsWith('Probe Window') && p.includes('actor=true'));
                if (bare.length > 0 && mapped.length === 0)
                    note('miss no-actor');
                else if (mapped.length > 0)
                    note('ok');
                else
                    note('miss no-window');
            } catch (e) {
                note(`t2 ${e}`);
            }
            try {
                client.get_subprocess().force_exit();
            } catch (e) {
            }
            return GLib.SOURCE_REMOVE;
        });
    }

    disable() {
        note('disable');
    }
}
