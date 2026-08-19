namespace GnomeShellRpc.Ui
{
	/** Params for {@link Display.get_window}. */
	public class WindowParams : OLLMrpc.CallParam
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("WindowParams", typeof(WindowParams));
		}

		/** Connection-local live handle from {@link OLLMrpc.Transport.Connection.export}. */
		public int object_id { get; set; default = 0; }
	}
}
