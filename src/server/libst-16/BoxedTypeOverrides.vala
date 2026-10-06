/**
 * {@link St.IconColors}, {@link St.Shadow}, and {@link St.ShadowHelper}.
 *
 * The server build has no St vapi for these records. Colors are four
 * bytes at the start of {@code StIconColors}. {@code StShadow} is a
 * color, then doubles at the next 8-byte boundary, then a
 * {@code gboolean} inset. {@code StShadowHelper} is opaque.
 */
namespace Gsr.Server.St
{
	[CCode (cname = "st_icon_colors_get_type")]
	private extern GLib.Type icon_colors_get_type();

	[CCode (cname = "st_shadow_get_type")]
	private extern GLib.Type shadow_get_type();

	[CCode (cname = "st_shadow_helper_get_type")]
	private extern GLib.Type shadow_helper_get_type();

	[CCode (cname = "st_icon_colors_new")]
	private extern void* icon_colors_new();

	[CCode (cname = "st_shadow_new")]
	private extern void* shadow_new(
		global::Cogl.Color* color,
		double xoffset,
		double yoffset,
		double blur,
		double spread,
		bool inset
	);

	public abstract class BoxedNums : OLLMrpc.Bin.TypeOverride
	{
		protected static Gee.ArrayList<GLib.Value?> nums(double[] xs)
		{
			var list = new Gee.ArrayList<GLib.Value?>();
			foreach (var x in xs) {
				var v = GLib.Value(typeof(double));
				v.set_double(x);
				list.add(v);
			}
			return list;
		}

		protected static Gee.ArrayList<GLib.Value?> zeros(int n)
		{
			return nums(new double[n]);
		}

		protected static double num(Gee.ArrayList<GLib.Value?> fields, int i)
		{
			return fields.get(i).get_double();
		}

		protected static void read_color(uint8* p, double[] xs, int at)
		{
			xs[at] = p[0];
			xs[at + 1] = p[1];
			xs[at + 2] = p[2];
			xs[at + 3] = p[3];
		}
	}

	public class IconColorsOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return icon_colors_get_type(); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(16);
			}
			unowned var p = (uint8*) src.get_boxed();
			var xs = new double[16];
			for (var i = 0; i < 4; i++) {
				read_color(p + i * 4, xs, i * 4);
			}
			return nums(xs);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 16;
			var colors = icon_colors_new();
			unowned var p = (uint8*) colors;
			for (var i = 0; i < 16; i++) {
				p[i] = (uint8) num(fields, index + i);
			}
			var v = GLib.Value(icon_colors_get_type());
			v.take_boxed(colors);
			return v;
		}
	}

	public class ShadowOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return shadow_get_type(); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(9);
			}
			unowned var p = (uint8*) src.get_boxed();
			var xs = new double[9];
			read_color(p, xs, 0);
			double xoffset = 0;
			double yoffset = 0;
			double blur = 0;
			double spread = 0;
			GLib.Memory.copy(&xoffset, p + 8, sizeof(double));
			GLib.Memory.copy(&yoffset, p + 16, sizeof(double));
			GLib.Memory.copy(&blur, p + 24, sizeof(double));
			GLib.Memory.copy(&spread, p + 32, sizeof(double));
			int inset = 0;
			GLib.Memory.copy(&inset, p + 40, sizeof(int));
			xs[4] = xoffset;
			xs[5] = yoffset;
			xs[6] = blur;
			xs[7] = spread;
			xs[8] = inset;
			return nums(xs);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 9;
			var color = global::Cogl.Color();
			color.red = (uint8) num(fields, index);
			color.green = (uint8) num(fields, index + 1);
			color.blue = (uint8) num(fields, index + 2);
			color.alpha = (uint8) num(fields, index + 3);
			var shadow = shadow_new(
				&color,
				num(fields, index + 4),
				num(fields, index + 5),
				num(fields, index + 6),
				num(fields, index + 7),
				num(fields, index + 8) != 0);
			var v = GLib.Value(shadow_get_type());
			v.take_boxed(shadow);
			return v;
		}
	}

	public class ShadowHelperOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return shadow_helper_get_type(); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 0;
			return GLib.Value(shadow_helper_get_type());
		}
	}

	public void register_boxed_types()
	{
		OLLMrpc.Bin.TypeOverride.register(new IconColorsOverride());
		OLLMrpc.Bin.TypeOverride.register(new ShadowOverride());
		OLLMrpc.Bin.TypeOverride.register(new ShadowHelperOverride());
	}
}
