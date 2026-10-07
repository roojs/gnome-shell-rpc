/**
 * Gate: a handler that does not write the boolean return, same contract
 * as {@code OLLMrpc.Live.Subscription.emit}.
 *
 * The signal uses {@code g_signal_accumulator_true_handled}, the same
 * stop-on-true rule as Clutter {@code captured-event}. A true return
 * stops the chain, so a later {@code button-release-event} would not run.
 *
 *   meson compile -C build button-release-chain-gate
 *   timeout 5 ./build/tests/call-sync-repro/button-release-chain-gate
 *
 * FAIL → the unset return stops the next handler. Writing false into
 *        the return would be the change that makes this pass.
 * PASS → the next handler still runs. That write would not change this.
 */

[CCode (cname = "button_release_chain_signal", cheader_filename = "button-release-chain-signal.h")]
extern uint chain_signal(GLib.Type type);

[CCode (cname = "g_signal_emit", cheader_filename = "glib-object.h")]
extern void signal_emit_bool(
	GLib.Object instance,
	uint signal_id,
	GLib.Quark detail,
	out bool return_value);

[CCode (cname = "g_signal_connect_data", cheader_filename = "glib-object.h")]
extern ulong connect_data(
	GLib.Object instance,
	string detailed_signal,
	GLib.Callback handler,
	void* data,
	GLib.DestroyNotify? destroy_data,
	GLib.ConnectFlags flags);

class Probe : GLib.Object
{
}

static uint phase_id;
static int followed;

/**
 * Same as {@code Subscription.emit}: do not write the return slot.
 */
static void ignore_return(
	GLib.Closure closure,
	[CCode (type = "GValue*")] GLib.Value? return_value,
	[CCode (array_length_cname = "n_param_values", array_length_pos = 2.5, array_length_type = "guint")]
	GLib.Value[] param_values,
	void* invocation_hint,
	void* marshal_data
) {
}

[CCode (has_target = false)]
delegate bool PhaseCb(Probe probe, void* data);

static bool stop_cb(Probe probe, void* data)
{
	return true;
}

static bool count_cb(Probe probe, void* data)
{
	followed++;
	return false;
}

static void connect_ignore(Probe probe)
{
	var closure = new GLib.Closure.simple((uint) GLib.Closure.SIZE, probe);
	closure.ref();
	closure.sink();
	closure.set_marshal((GLib.ClosureMarshal) ignore_return);
	closure.set_meta_marshal(probe, (GLib.ClosureMarshal) ignore_return);
	GLib.Signal.connect_closure(probe, "phase", closure, false);
}

static bool emit_phase(Probe probe)
{
	bool stopped = false;
	signal_emit_bool(probe, phase_id, 0, out stopped);
	return stopped;
}

int main()
{
	phase_id = chain_signal(typeof(Probe));
	if (phase_id == 0) {
		stderr.printf("FAIL button-release-chain-gate: signal_new\n");
		return 1;
	}

	var control = new Probe();
	connect_data(control, "phase", (GLib.Callback) stop_cb, null, null, 0);
	connect_data(control, "phase", (GLib.Callback) count_cb, null, null, 0);
	followed = 0;
	if (!emit_phase(control) || followed != 0) {
		stderr.printf(
			"FAIL button-release-chain-gate: true return did not stop the chain followed=%d\n",
			followed);
		return 1;
	}

	var probe = new Probe();
	connect_ignore(probe);
	connect_data(probe, "phase", (GLib.Callback) count_cb, null, null, 0);
	followed = 0;
	var stopped = emit_phase(probe);
	if (stopped || followed != 1) {
		stderr.printf(
			"FAIL button-release-chain-gate: unset return stopped emission followed=%d stopped=%s\n",
			followed, stopped.to_string());
		return 1;
	}
	stderr.printf(
		"PASS button-release-chain-gate: unset return did not stop the next handler\n");
	return 0;
}
