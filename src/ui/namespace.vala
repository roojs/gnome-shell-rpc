/**
 * Server-side desktop snapshots and {@link Display} RPC handlers.
 *
 * {@link Window}, {@link Display}, and {@link Workspace} are serializable
 * snapshots of what the user sees — not live {@link Meta.Window} pointers.
 * Out-of-process clients decode these under {@code meta-mini} (GJS) or
 * {@link GnomeShellRpc.FakeShell} (throwaway Vala bar).
 */
namespace GnomeShellRpc.Ui
{
}
