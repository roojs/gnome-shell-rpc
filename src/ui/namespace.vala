/**
 * Server-side desktop snapshots and {@link Display} RPC handlers.
 *
 * {@link Window}, {@link Display}, and {@link Workspace} are serializable
 * snapshots of what the user sees — not live {@link Meta.Window} pointers.
 * Out-of-process clients decode these and hold proxies under
 * {@link GnomeShellRpc.Remote}.
 */
namespace GnomeShellRpc.Ui
{
}
