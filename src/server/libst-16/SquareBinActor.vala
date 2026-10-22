/**
 * Server peer for {@code Shell.SquareBin}. Stock
 * {@code shell_square_bin_get_preferred_width} returns the
 * preferred height. A plain {@code St.Bin} reports the label
 * width, and the application grid then overlaps the next cell.
 */
namespace Gsr.Server.St
{
	public class SquareBinActor : global::St.Bin
	{
		/**
		 * Width is the unconstrained height, as in
		 * {@code shell-square-bin.c}.
		 */
		public override void get_preferred_width(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			this.get_preferred_height(-1, out min_width_p, out natural_width_p);
		}
	}

	/**
	 * ''Gsr-St-SquareBin.new'' — mint {@link SquareBinActor}.
	 * {@code St-Bin.new} stays a plain bin.
	 */
	public class SquareBin : GLib.Object
	{
		public static void rpc_register()
		{
			/* add_child requires the child GType in the alias map.
			   Stock StBin already is. This peer is a second GType. */
			OLLMrpc.Bin.register_alias("St-Bin", typeof(SquareBinActor));
			var helper = new SquareBin();
			OLLMrpc.Request.add_class(
				"Gsr-St-SquareBin", typeof(SquareBin),
				"new", "t");
			OLLMrpc.Request.register_live("Gsr-St-SquareBin", helper);
		}

		[CCode (cname = "gnome_shell_rpc_st_square_bin_create")]
		public SquareBin()
		{
		}

		/**
		 * ''Gsr-St-SquareBin.new'' — square peer. {@code old_lid}
		 * is the plain bin the parent walk already leased.
		 * Drop that lease. It has no children yet.
		 */
		[CCode (cname = "gsr_server_st_square_bin_new")]
		public void mint(OLLMrpc.Request request, uint64 old_lid)
		{
			if (old_lid != 0) {
				request.connection.leases.unset((int) old_lid);
			}
			var created = new SquareBinActor();
			request.connection.export(created);
			request.reply(new OLLMrpc.Response() {
				retval = OLLMrpc.val("o", created),
			});
		}
	}
}
