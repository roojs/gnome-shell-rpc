/**
 * Server-side desktop snapshots and live Meta RPC handlers.
 *
 * {@link Window}, {@link Display}, and {@link Workspace} are serializable
 * snapshots of what the user sees — not live {@link Meta.Window} pointers.
 * {@link Compositor} is the live {@code Meta-Compositor} handler.
 * {@link Backend} is the live {@code Meta-Backend} handler.
 * Out-of-process clients decode snapshots under {@code meta-mini} (GJS) or
 * {@link GnomeShellRpc.FakeShell} (throwaway Vala bar).
 */
namespace GnomeShellRpc.Ui
{
}
