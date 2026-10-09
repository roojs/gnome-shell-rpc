/**
 * Shared serializable value types for compositor and RPC clients.
 *
 * Pure {@link OLLMrpc.Bin.Serializable} DTOs with no {@link Meta} or proxy
 * logic. {@link Rectangle} is the first type here.
 *
 * == Example ==
 *
 * {{{
 * Gsr.Shared.rpc_register();
 * var r = new Gsr.Shared.Rectangle() {
 *     x = 0, y = 0, width = 100, height = 40,
 * };
 * }}}
 */
namespace Gsr.Shared
{
	public void rpc_register()
	{
		Rectangle.rpc_register();
		ClutterEventState.rpc_register();
		Window.rpc_register();
		Workspace.rpc_register();
	}
}
