/**
 * Isolated prove: Vala class + dummy GIR marker. inject.sh replaces the
 * marker with search.function.gir (nested GStrv). Not product Shell-16.
 */
namespace GsrSearch
{
	public class AppSystem : GLib.Object
	{
		public static string ping()
		{
			return "pong";
		}

		/* Temporary vala_gir marker — inject.sh removes this function. */
		public static void gsr_placeholder_nested_gstrv()
		{
		}
	}
}
