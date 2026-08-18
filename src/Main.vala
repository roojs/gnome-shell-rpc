namespace GnomeShellRpc
{
    /**
     * Process entry: configure mutter, install {@link Plugin}, run the loop.
     *
     * This is Gala's `Main.vala` shape without Gala chrome. Nested testing
     * uses `--wayland --nested` (mutter 48 on this distro has no `--devkit`).
     *
     * == Example ==
     *
     * {{{
     * dbus-run-session ./build/src/gnome-shell-rpc --wayland --nested
     * }}}
     */
    public static int main (string[] args)
    {
        var ctx = new Meta.Context ("Mutter(GnomeShellRpc)");
        try {
            ctx.configure (ref args);
        } catch (GLib.Error e) {
            GLib.stderr.printf ("Error initializing: %s\n", e.message);
            return 1;
        }

        ctx.set_plugin_gtype (typeof (GnomeShellRpc.Plugin));

        try {
            ctx.setup ();
        } catch (GLib.Error e) {
            GLib.stderr.printf ("Failed to setup: %s\n", e.message);
            return 1;
        }

        try {
            ctx.start ();
            ctx.run_main_loop ();
        } catch (GLib.Error e) {
            GLib.stderr.printf ("Failed to start: %s\n", e.message);
            return 1;
        }

        return 0;
    }
}
