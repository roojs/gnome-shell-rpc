namespace GnomeShellRpc.GiRpcMock
{
	/**
	 * Non-GIR wire methods for mock server boot and import smokes.
	 *
	 * Return false for GI-shaped calls so libocrpc {@link GiMock} runs.
	 */
	public class HelperMock : GLib.Object, OLLMrpc.MockDispatch
	{
		public bool dispatch(OLLMrpc.Request request)
		{
			switch (request.method) {
			/* Leased object retval — stack cases here (fall through). */
			case "RPC-Bootstrap.get_display":
				var token = new GLib.Object();
				request.connection.export(token);
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("o", token),
				});
				return true;

			default:
				break;
			}

			if (request.method.has_prefix("Helper-")) {
				GLib.warning("HelperMock: stub void reply for %s",
					request.method);
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return true;
			}

			return false;
		}
	}
}
