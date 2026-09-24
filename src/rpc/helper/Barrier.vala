/**
 * Nested Wayland has no {@code MetaBarrierImpl}. Stock {@code meta_barrier_new}
 * fails {@code GInitable}. {@code GLib.Object.new} skips that check, so the
 * real {@link Meta.Barrier} is returned and the wire schema stays
 * {@code MetaBarrier}. {@code priv->impl} stays null: {@code release} does
 * nothing, and {@code hit} / {@code leave} never fire.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Barrier : GLib.Object
	{
		[CCode (cname = "gnome_shell_rpc_rpc_helper_barrier_create")]
		public Barrier()
		{
		}

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Meta-Barrier", typeof(Barrier), "new", "oiiiiuu", null);
			OLLMrpc.Request.register_live("Meta-Barrier", new Barrier());
		}

		[CCode (cname = "gnome_shell_rpc_rpc_helper_barrier_new")]
		public void mint(
			OLLMrpc.Request request,
			Meta.Backend backend,
			int x1,
			int y1,
			int x2,
			int y2,
			uint directions,
			uint flags
		) {
			var created = (Meta.Barrier) GLib.Object.new(
				typeof(Meta.Barrier),
				"backend", backend,
				"x1", x1,
				"y1", y1,
				"x2", x2,
				"y2", y2,
				"directions", (Meta.BarrierDirection) directions,
				"flags", (Meta.BarrierFlags) flags
			);
			request.connection.export(created);
			request.reply(new OLLMrpc.Response() {
				retval = OLLMrpc.val("o", created),
			});
		}
	}
}
