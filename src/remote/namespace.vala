/**
 * Live RPC client proxies for compositor state.
 *
 * {@link Session} owns {@link OLLMrpc.Client}. {@link Display} and
 * {@link Window} hold handles and issue {@code RPC-Display.*} calls.
 * Class names are plain nouns — {@link Window}, not RemoteWindow.
 *
 * == Example ==
 *
 * {{{
 * var session = new GnomeShellRpc.Remote.Session();
 * yield session.connect();
 * yield session.display.list_windows();
 * yield session.display.focused_window.minimize();
 * }}}
 */
namespace GnomeShellRpc.Remote
{
}
