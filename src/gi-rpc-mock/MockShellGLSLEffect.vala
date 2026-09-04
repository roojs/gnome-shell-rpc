namespace GnomeShellRpc.GiRpcMock
{
	/**
	 * Minimal server-side stand-in for compositor {@code Shell-GLSLEffect}.
	 *
	 * Real server registers {@link GnomeShellRpc.Rpc.Helper.GLSLEffect}; mock
	 * only needs a wire alias so lease export encodes for the client stub.
	 */
	public class MockShellGLSLEffect : GLib.Object
	{
	}
}
