/**
 * Remote representation of desktop state for RPC clients.
 *
 * {@link Window}, {@link Display}, and {@link Workspace} are serializable
 * snapshots of what the user sees — not live {@link Meta.Window} pointers.
 * GTK chrome in the out-of-process shell (**0.3**) consumes these over RPC.
 */
namespace GnomeShellRpc.Ui
{
}
