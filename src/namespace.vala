/**
 * Nested mutter compositor exposing desktop state over GObject RPC.
 *
 * {@link Plugin} is the in-process {@link Meta.Plugin}. The process starts
 * a {@link Meta.Context} the same way Gala does: the Vala binary links
 * libmutter and calls {@link Meta.Context.set_plugin_gtype}. Stock mutter
 * is not loaded with `--mutter-plugin` yet.
 *
 * {@link GnomeShellRpc.Ui} types are the remote representation of what the
 * user sees. {@link GnomeShellRpc.Rpc.Server} listens on a Unix socket.
 *
 * == Example ==
 *
 * {{{
 * dbus-run-session ./build/src/gnome-shell-rpc --wayland --nested
 * }}}
 */
namespace GnomeShellRpc
{
}
