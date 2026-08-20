/**
 * Shared serializable value types for compositor and RPC clients.
 *
 * Pure {@link OLLMrpc.Bin.Serializable} DTOs with no {@link Meta} or proxy
 * logic. {@link Rectangle} is the first type here.
 *
 * == Example ==
 *
 * {{{
 * GnomeShellRpc.Shared.Rectangle.rpc_register();
 * var r = new GnomeShellRpc.Shared.Rectangle() {
 *     x = 0, y = 0, width = 100, height = 40,
 * };
 * }}}
 */
namespace GnomeShellRpc.Shared
{
}
