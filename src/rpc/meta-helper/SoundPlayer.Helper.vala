/**
 * Delivers {@link Meta.SoundPlayer} Override RPC (plan 0.5.7 C1).
 *
 * Phase 1: scaffold — {@link register_all} is a no-op.
 */
namespace GnomeShellRpc.Rpc.MetaHelper
{
	public class SoundPlayerHelper : GLib.Object
	{
		public static void register_all()
		{
		}

		public static void play_from_file(
			Meta.SoundPlayer player,
			string uri,
			string description,
			uint64 cancel_id
		)
		{
			GLib.File? file = null;
			if (uri != "") {
				file = GLib.File.new_for_uri(uri);
			}
			var cancel = GnomeShellRpc.Rpc.CancellableBridge.lookup(cancel_id);
			player.play_from_file(file, description, cancel);
		}

		public static void play_from_theme(
			Meta.SoundPlayer player,
			string name,
			string description,
			uint64 cancel_id
		)
		{
			var cancel = GnomeShellRpc.Rpc.CancellableBridge.lookup(cancel_id);
			player.play_from_theme(name, description, cancel);
		}
	}
}
