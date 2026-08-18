/**
 * Nested mutter compositor that will later expose Meta* over GObject RPC.
 *
 * {@link Plugin} is the in-process {@link Meta.Plugin}. The process starts
 * a {@link Meta.Context} the same way Gala does: the Vala binary links
 * libmutter and calls {@link Meta.Context.set_plugin_gtype}. Stock mutter
 * is not loaded with `--mutter-plugin` yet.
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
