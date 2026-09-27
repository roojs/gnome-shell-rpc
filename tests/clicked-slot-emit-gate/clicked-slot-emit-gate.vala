/*
 * Out of mainline. Same shape the generator emits for a class field that
 * is also a signal: a plain virtual at the slot, and a signal that is not
 * virtual.
 *
 * AppIcon overrides the virtual and does not connect the signal. A click
 * notification emits the signal. This program does that emit and counts
 * how many times the override runs.
 *
 * Exit 1 while the override stays at 0. That is the reproduction.
 */
public class SlotButton : GLib.Object {
	[CCode (cname = "gsr_repro_clicked_vfunc", vfunc_name = "clicked")]
	public virtual void clicked_vfunc (int clicked_button) {
	}

	[CCode (cname = "clicked")]
	public signal void signal_clicked (int clicked_button);

	static construct {
		gsr_repro_bind_clicked_slot (typeof (SlotButton));
	}
}

public class AppIcon : SlotButton {
	public static int hits;

	public override void clicked_vfunc (int clicked_button) {
		AppIcon.hits++;
	}
}

[CCode (cname = "gsr_repro_bind_clicked_slot")]
extern void gsr_repro_bind_clicked_slot (GLib.Type type);

public static int main (string[] args) {
	var icon = new AppIcon ();
	icon.signal_clicked (1);
	stdout.printf ("clicked-slot-emit-gate: hits=%d\n", AppIcon.hits);
	if (AppIcon.hits != 1) {
		stdout.printf ("clicked-slot-emit-gate: FAIL emit did not run clicked_vfunc\n");
		return 1;
	}
	stdout.printf ("clicked-slot-emit-gate: ok\n");
	return 0;
}
