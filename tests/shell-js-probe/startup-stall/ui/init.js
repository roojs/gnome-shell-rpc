/* Startup stall probe. Same boot as stock ui/init.js.
 * GI_RPC_JS_OVERRIDE_DIR=tests/shell-js-probe/startup-stall
 * Logs use prefix gsr-startup-stall:
 */
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import './environment.js';
import {formatError} from '../misc/errorUtils.js';

const state = {
    ticks: 0,
    frames: 0,
    started: false,
    poked: false,
    framesAtPoke: 0,
};

function probeLog(msg) {
    GLib.log_structured('GNOME Shell', GLib.LogLevelFlags.LEVEL_MESSAGE, {
        'MESSAGE': `gsr-startup-stall: ${msg}`,
    });
}

imports._promiseNative.setMainLoopHook(() => {
    probeLog('hook');
    try {
        const stage = global.stage;
        if (stage) {
            stage.connect('before-update', () => {
                state.frames++;
            });
            probeLog('frame-hook');
        } else {
            probeLog('no-stage');
        }
    } catch (e) {
        probeLog(`frame-hook-err ${e}`);
    }
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
        state.ticks++;
        probeLog(`tick ${state.ticks} frames=${state.frames} started=${state.started}`);
        if (state.started && !state.poked && state.ticks >= 8) {
            state.poked = true;
            state.framesAtPoke = state.frames;
            try {
                const backend = Clutter.get_default_backend();
                const seat = backend.get_default_seat();
                const virt = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);
                const x = global.stage.width / 2;
                const y = 16;
                virt.notify_absolute_motion(global.get_current_time(), x, y);
                probeLog(`poke ${x},${y} frames=${state.frames}`);
            } catch (e) {
                probeLog(`poke-err ${e}`);
            }
        }
        if (state.poked && state.ticks === 10) {
            const grew = state.frames > state.framesAtPoke;
            probeLog(`after-poke frames=${state.frames} atPoke=${state.framesAtPoke} grew=${grew}`);
            probeLog(grew ? 'ok' : 'miss');
        }
        return GLib.SOURCE_CONTINUE;
    });
    GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
        import('./main.js').then(main => {
            main.start().then(() => {
                state.started = true;
                probeLog(`started frames=${state.frames}`);
            }).catch(e => {
                probeLog(`start-error ${formatError(e)}`);
            });
        }).catch(e => {
            const error = new GLib.Error(
                Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, formatError(e));
            global.context.terminate_with_error(error);
        });
        return GLib.SOURCE_REMOVE;
    });
    global.context.run_main_loop();
});
