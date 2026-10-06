/**
 * Client rebuild of the boxed records in
 * {@code Gsr.Server.Clutter.BoxedTypeOverrides} and
 * {@code Gsr.Server.St.BoxedTypeOverrides}.
 *
 * Field order matches the server. Opaque records consume nothing.
 */
namespace Shell
{
	internal abstract class BoxedNums : OLLMrpc.Bin.TypeOverride
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

		[CCode (cname = "graphene_matrix_to_float")]
		protected static extern void matrix_to_float(
			[CCode (type = "const graphene_matrix_t*")] Graphene.Matrix* m,
			[CCode (array_length = false)] float[] dest);

		[CCode (cname = "graphene_vec2_to_float")]
		protected static extern void vec2_to_float(
			[CCode (type = "const graphene_vec2_t*")] Graphene.Vec2* v,
			[CCode (array_length = false)] float[] dest);

		[CCode (cname = "graphene_vec3_to_float")]
		protected static extern void vec3_to_float(
			[CCode (type = "const graphene_vec3_t*")] Graphene.Vec3* v,
			[CCode (array_length = false)] float[] dest);

		[CCode (cname = "graphene_vec4_to_float")]
		protected static extern void vec4_to_float(
			[CCode (type = "const graphene_vec4_t*")] Graphene.Vec4* v,
			[CCode (array_length = false)] float[] dest);

		[CCode (cname = "graphene_frustum_get_planes")]
		protected static extern void frustum_planes(
			[CCode (type = "const graphene_frustum_t*")] Graphene.Frustum* f,
			[CCode (array_length = false)] Graphene.Plane[] planes);
	}

	internal class MarginOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Clutter.Margin); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(4);
			}
			unowned var m = (Clutter.Margin*) src.get_boxed();
			return nums({
				(double) m.left, (double) m.right,
				(double) m.top, (double) m.bottom
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 4;
			var m = (Clutter.Margin*) GLib.malloc0(sizeof(Clutter.Margin));
			m.left = (float) num(fields, index);
			m.right = (float) num(fields, index + 1);
			m.top = (float) num(fields, index + 2);
			m.bottom = (float) num(fields, index + 3);
			var v = GLib.Value(typeof(Clutter.Margin));
			v.take_boxed(m);
			return v;
		}
	}

	internal class PerspectiveOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Clutter.Perspective); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(4);
			}
			unowned var p = (Clutter.Perspective*) src.get_boxed();
			return nums({
				(double) p.fovy, (double) p.aspect,
				(double) p.z_near, (double) p.z_far
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 4;
			var p = (Clutter.Perspective*) GLib.malloc0(sizeof(Clutter.Perspective));
			p.fovy = (float) num(fields, index);
			p.aspect = (float) num(fields, index + 1);
			p.z_near = (float) num(fields, index + 2);
			p.z_far = (float) num(fields, index + 3);
			var v = GLib.Value(typeof(Clutter.Perspective));
			v.take_boxed(p);
			return v;
		}
	}

	internal class CoglColorOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Cogl.Color); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(4);
			}
			unowned var c = (Cogl.Color*) src.get_boxed();
			return nums({
				(double) c.red, (double) c.green,
				(double) c.blue, (double) c.alpha
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 4;
			var c = (Cogl.Color*) GLib.malloc0(sizeof(Cogl.Color));
			c.red = (uint8) num(fields, index);
			c.green = (uint8) num(fields, index + 1);
			c.blue = (uint8) num(fields, index + 2);
			c.alpha = (uint8) num(fields, index + 3);
			var v = GLib.Value(typeof(Cogl.Color));
			v.take_boxed(c);
			return v;
		}
	}

	internal class GrapheneMatrixOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Matrix); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(16);
			}
			unowned var m = (Graphene.Matrix*) src.get_boxed();
			float f[16];
			matrix_to_float(m, f);
			var xs = new double[16];
			for (var i = 0; i < 16; i++) {
				xs[i] = (double) f[i];
			}
			return nums(xs);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 16;
			float f[16];
			for (var i = 0; i < 16; i++) {
				f[i] = (float) num(fields, index + i);
			}
			var m = (Graphene.Matrix*) GLib.malloc0(sizeof(Graphene.Matrix));
			m.init_from_float(f);
			var v = GLib.Value(typeof(Graphene.Matrix));
			v.take_boxed(m);
			return v;
		}
	}

	internal class GraphenePoint3DOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Point3D); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(3);
			}
			unowned var p = (Graphene.Point3D*) src.get_boxed();
			return nums({ (double) p.x, (double) p.y, (double) p.z });
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 3;
			var p = (Graphene.Point3D*) GLib.malloc0(sizeof(Graphene.Point3D));
			p.x = (float) num(fields, index);
			p.y = (float) num(fields, index + 1);
			p.z = (float) num(fields, index + 2);
			var v = GLib.Value(typeof(Graphene.Point3D));
			v.take_boxed(p);
			return v;
		}
	}

	internal class GrapheneVec2Override : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Vec2); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(2);
			}
			unowned var vec = (Graphene.Vec2*) src.get_boxed();
			float f[2];
			vec2_to_float(vec, f);
			return nums({ (double) f[0], (double) f[1] });
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 2;
			float f[2] = {
				(float) num(fields, index),
				(float) num(fields, index + 1)
			};
			var vec = (Graphene.Vec2*) GLib.malloc0(sizeof(Graphene.Vec2));
			vec.init_from_float(f);
			var v = GLib.Value(typeof(Graphene.Vec2));
			v.take_boxed(vec);
			return v;
		}
	}

	internal class GrapheneVec3Override : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Vec3); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(3);
			}
			unowned var vec = (Graphene.Vec3*) src.get_boxed();
			float f[3];
			vec3_to_float(vec, f);
			return nums({ (double) f[0], (double) f[1], (double) f[2] });
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 3;
			float f[3] = {
				(float) num(fields, index),
				(float) num(fields, index + 1),
				(float) num(fields, index + 2)
			};
			var vec = (Graphene.Vec3*) GLib.malloc0(sizeof(Graphene.Vec3));
			vec.init_from_float(f);
			var v = GLib.Value(typeof(Graphene.Vec3));
			v.take_boxed(vec);
			return v;
		}
	}

	internal class GrapheneVec4Override : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Vec4); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(4);
			}
			unowned var vec = (Graphene.Vec4*) src.get_boxed();
			float f[4];
			vec4_to_float(vec, f);
			return nums({
				(double) f[0], (double) f[1], (double) f[2], (double) f[3]
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 4;
			float f[4] = {
				(float) num(fields, index),
				(float) num(fields, index + 1),
				(float) num(fields, index + 2),
				(float) num(fields, index + 3)
			};
			var vec = (Graphene.Vec4*) GLib.malloc0(sizeof(Graphene.Vec4));
			vec.init_from_float(f);
			var v = GLib.Value(typeof(Graphene.Vec4));
			v.take_boxed(vec);
			return v;
		}
	}

	internal class GrapheneQuaternionOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Quaternion); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(4);
			}
			var q = *(Graphene.Quaternion*) src.get_boxed();
			var vec = q.to_vec4();
			float f[4];
			vec4_to_float(&vec, f);
			return nums({
				(double) f[0], (double) f[1], (double) f[2], (double) f[3]
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 4;
			var q = (Graphene.Quaternion*) GLib.malloc0(sizeof(Graphene.Quaternion));
			q.init(
				(float) num(fields, index),
				(float) num(fields, index + 1),
				(float) num(fields, index + 2),
				(float) num(fields, index + 3));
			var v = GLib.Value(typeof(Graphene.Quaternion));
			v.take_boxed(q);
			return v;
		}
	}

	internal class GrapheneBoxOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Box); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(6);
			}
			var box = *(Graphene.Box*) src.get_boxed();
			var mn = box.get_min();
			var mx = box.get_max();
			return nums({
				(double) mn.x, (double) mn.y, (double) mn.z,
				(double) mx.x, (double) mx.y, (double) mx.z
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 6;
			var mn = Graphene.Point3D();
			var mx = Graphene.Point3D();
			mn.x = (float) num(fields, index);
			mn.y = (float) num(fields, index + 1);
			mn.z = (float) num(fields, index + 2);
			mx.x = (float) num(fields, index + 3);
			mx.y = (float) num(fields, index + 4);
			mx.z = (float) num(fields, index + 5);
			var box = (Graphene.Box*) GLib.malloc0(sizeof(Graphene.Box));
			box.init(mn, mx);
			var v = GLib.Value(typeof(Graphene.Box));
			v.take_boxed(box);
			return v;
		}
	}

	internal class GrapheneEulerOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Euler); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(4);
			}
			var e = *(Graphene.Euler*) src.get_boxed();
			return nums({
				(double) e.get_x(), (double) e.get_y(), (double) e.get_z(),
				(double) e.get_order()
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 4;
			var e = (Graphene.Euler*) GLib.malloc0(sizeof(Graphene.Euler));
			e.init_with_order(
				(float) num(fields, index),
				(float) num(fields, index + 1),
				(float) num(fields, index + 2),
				(Graphene.EulerOrder) (int) num(fields, index + 3));
			var v = GLib.Value(typeof(Graphene.Euler));
			v.take_boxed(e);
			return v;
		}
	}

	internal class GraphenePlaneOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Plane); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(4);
			}
			var plane = *(Graphene.Plane*) src.get_boxed();
			var n = plane.get_normal();
			return nums({
				(double) n.get_x(), (double) n.get_y(), (double) n.get_z(),
				(double) plane.get_constant()
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 4;
			var n = Graphene.Vec3();
			n.init(
				(float) num(fields, index),
				(float) num(fields, index + 1),
				(float) num(fields, index + 2));
			var plane = (Graphene.Plane*) GLib.malloc0(sizeof(Graphene.Plane));
			plane.init(n, (float) num(fields, index + 3));
			var v = GLib.Value(typeof(Graphene.Plane));
			v.take_boxed(plane);
			return v;
		}
	}

	internal class GrapheneRayOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Ray); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(6);
			}
			var ray = *(Graphene.Ray*) src.get_boxed();
			var origin = ray.get_origin();
			var dir = ray.get_direction();
			return nums({
				(double) origin.x, (double) origin.y, (double) origin.z,
				(double) dir.get_x(), (double) dir.get_y(), (double) dir.get_z()
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 6;
			var origin = Graphene.Point3D();
			origin.x = (float) num(fields, index);
			origin.y = (float) num(fields, index + 1);
			origin.z = (float) num(fields, index + 2);
			var dir = Graphene.Vec3();
			dir.init(
				(float) num(fields, index + 3),
				(float) num(fields, index + 4),
				(float) num(fields, index + 5));
			var ray = (Graphene.Ray*) GLib.malloc0(sizeof(Graphene.Ray));
			ray.init(origin, dir);
			var v = GLib.Value(typeof(Graphene.Ray));
			v.take_boxed(ray);
			return v;
		}
	}

	internal class GrapheneSphereOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Sphere); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(4);
			}
			var sphere = *(Graphene.Sphere*) src.get_boxed();
			var c = sphere.get_center();
			return nums({
				(double) c.x, (double) c.y, (double) c.z,
				(double) sphere.get_radius()
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 4;
			var c = Graphene.Point3D();
			c.x = (float) num(fields, index);
			c.y = (float) num(fields, index + 1);
			c.z = (float) num(fields, index + 2);
			var sphere = (Graphene.Sphere*) GLib.malloc0(sizeof(Graphene.Sphere));
			sphere.init(c, (float) num(fields, index + 3));
			var v = GLib.Value(typeof(Graphene.Sphere));
			v.take_boxed(sphere);
			return v;
		}
	}

	internal class GrapheneTriangleOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Triangle); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(9);
			}
			var tri = *(Graphene.Triangle*) src.get_boxed();
			Graphene.Vec3 a, b, c;
			tri.get_vertices(out a, out b, out c);
			return nums({
				(double) a.get_x(), (double) a.get_y(), (double) a.get_z(),
				(double) b.get_x(), (double) b.get_y(), (double) b.get_z(),
				(double) c.get_x(), (double) c.get_y(), (double) c.get_z()
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 9;
			var a = Graphene.Vec3();
			var b = Graphene.Vec3();
			var c = Graphene.Vec3();
			a.init(
				(float) num(fields, index),
				(float) num(fields, index + 1),
				(float) num(fields, index + 2));
			b.init(
				(float) num(fields, index + 3),
				(float) num(fields, index + 4),
				(float) num(fields, index + 5));
			c.init(
				(float) num(fields, index + 6),
				(float) num(fields, index + 7),
				(float) num(fields, index + 8));
			var tri = (Graphene.Triangle*) GLib.malloc0(sizeof(Graphene.Triangle));
			tri.init_from_vec3(a, b, c);
			var v = GLib.Value(typeof(Graphene.Triangle));
			v.take_boxed(tri);
			return v;
		}
	}

	internal class GrapheneQuadOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Quad); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(8);
			}
			var quad = *(Graphene.Quad*) src.get_boxed();
			var xs = new double[8];
			for (var i = 0; i < 4; i++) {
				unowned var p = quad.get_point(i);
				xs[i * 2] = (double) p.x;
				xs[i * 2 + 1] = (double) p.y;
			}
			return nums(xs);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 8;
			var points = new Graphene.Point[4];
			for (var i = 0; i < 4; i++) {
				points[i] = Graphene.Point();
				points[i].x = (float) num(fields, index + i * 2);
				points[i].y = (float) num(fields, index + i * 2 + 1);
			}
			var quad = (Graphene.Quad*) GLib.malloc0(sizeof(Graphene.Quad));
			quad.init(points[0], points[1], points[2], points[3]);
			var v = GLib.Value(typeof(Graphene.Quad));
			v.take_boxed(quad);
			return v;
		}
	}

	internal class GrapheneFrustumOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Frustum); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(24);
			}
			unowned var frustum = (Graphene.Frustum*) src.get_boxed();
			var planes = new Graphene.Plane[6];
			frustum_planes(frustum, planes);
			var xs = new double[24];
			for (var i = 0; i < 6; i++) {
				var n = planes[i].get_normal();
				xs[i * 4] = (double) n.get_x();
				xs[i * 4 + 1] = (double) n.get_y();
				xs[i * 4 + 2] = (double) n.get_z();
				xs[i * 4 + 3] = (double) planes[i].get_constant();
			}
			return nums(xs);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 24;
			Graphene.Plane planes[6];
			for (var i = 0; i < 6; i++) {
				var n = Graphene.Vec3();
				var at = index + i * 4;
				n.init(
					(float) num(fields, at),
					(float) num(fields, at + 1),
					(float) num(fields, at + 2));
				planes[i] = Graphene.Plane();
				planes[i].init(n, (float) num(fields, at + 3));
			}
			var frustum = (Graphene.Frustum*) GLib.malloc0(sizeof(Graphene.Frustum));
			frustum.init(
				planes[0], planes[1], planes[2],
				planes[3], planes[4], planes[5]);
			var v = GLib.Value(typeof(Graphene.Frustum));
			v.take_boxed(frustum);
			return v;
		}
	}

	internal class IconColorsOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(St.IconColors); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(16);
			}
			unowned var c = (St.IconColors*) src.get_boxed();
			return nums({
				(double) c.foreground.red, (double) c.foreground.green,
				(double) c.foreground.blue, (double) c.foreground.alpha,
				(double) c.warning.red, (double) c.warning.green,
				(double) c.warning.blue, (double) c.warning.alpha,
				(double) c.error.red, (double) c.error.green,
				(double) c.error.blue, (double) c.error.alpha,
				(double) c.success.red, (double) c.success.green,
				(double) c.success.blue, (double) c.success.alpha
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 16;
			var c = (St.IconColors*) GLib.malloc0(sizeof(St.IconColors));
			c.foreground.red = (uint8) num(fields, index);
			c.foreground.green = (uint8) num(fields, index + 1);
			c.foreground.blue = (uint8) num(fields, index + 2);
			c.foreground.alpha = (uint8) num(fields, index + 3);
			c.warning.red = (uint8) num(fields, index + 4);
			c.warning.green = (uint8) num(fields, index + 5);
			c.warning.blue = (uint8) num(fields, index + 6);
			c.warning.alpha = (uint8) num(fields, index + 7);
			c.error.red = (uint8) num(fields, index + 8);
			c.error.green = (uint8) num(fields, index + 9);
			c.error.blue = (uint8) num(fields, index + 10);
			c.error.alpha = (uint8) num(fields, index + 11);
			c.success.red = (uint8) num(fields, index + 12);
			c.success.green = (uint8) num(fields, index + 13);
			c.success.blue = (uint8) num(fields, index + 14);
			c.success.alpha = (uint8) num(fields, index + 15);
			var v = GLib.Value(typeof(St.IconColors));
			v.take_boxed(c);
			return v;
		}
	}

	internal class ShadowOverride : BoxedNums
	{
		public override GLib.Type override_type {
			get { return typeof(St.Shadow); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return zeros(9);
			}
			unowned var s = (St.Shadow*) src.get_boxed();
			return nums({
				(double) s.color.red, (double) s.color.green,
				(double) s.color.blue, (double) s.color.alpha,
				s.xoffset, s.yoffset, s.blur, s.spread,
				s.inset ? 1.0 : 0.0
			});
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 9;
			var s = (St.Shadow*) GLib.malloc0(sizeof(St.Shadow));
			s.color.red = (uint8) num(fields, index);
			s.color.green = (uint8) num(fields, index + 1);
			s.color.blue = (uint8) num(fields, index + 2);
			s.color.alpha = (uint8) num(fields, index + 3);
			s.xoffset = num(fields, index + 4);
			s.yoffset = num(fields, index + 5);
			s.blur = num(fields, index + 6);
			s.spread = num(fields, index + 7);
			s.inset = num(fields, index + 8) != 0;
			var v = GLib.Value(typeof(St.Shadow));
			v.take_boxed(s);
			return v;
		}
	}

	internal class EventSequenceOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Clutter.EventSequence); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 0;
			return GLib.Value(typeof(Clutter.EventSequence));
		}
	}

	internal class PaintContextOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Clutter.PaintContext); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 0;
			var v = GLib.Value(typeof(Clutter.PaintContext));
			v.set_object(null);
			return v;
		}
	}

	internal class PaintVolumeOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Clutter.PaintVolume); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 0;
			var v = GLib.Value(typeof(Clutter.PaintVolume));
			v.set_object(null);
			return v;
		}
	}

	internal class FrameClosureOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Cogl.FrameClosure); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 0;
			return GLib.Value(typeof(Cogl.FrameClosure));
		}
	}

	internal class MatrixEntryOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Cogl.MatrixEntry); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 0;
			return GLib.Value(typeof(Cogl.MatrixEntry));
		}
	}

	internal class ShadowHelperOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(St.ShadowHelper); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields, int index, out int consumed)
		{
			consumed = 0;
			return GLib.Value(typeof(St.ShadowHelper));
		}
	}

	internal void register_boxed_types()
	{
		OLLMrpc.Bin.TypeOverride.register(new MarginOverride());
		OLLMrpc.Bin.TypeOverride.register(new PerspectiveOverride());
		OLLMrpc.Bin.TypeOverride.register(new CoglColorOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneMatrixOverride());
		OLLMrpc.Bin.TypeOverride.register(new GraphenePoint3DOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneVec2Override());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneVec3Override());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneVec4Override());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneQuaternionOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneBoxOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneEulerOverride());
		OLLMrpc.Bin.TypeOverride.register(new GraphenePlaneOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneRayOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneSphereOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneTriangleOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneQuadOverride());
		OLLMrpc.Bin.TypeOverride.register(new GrapheneFrustumOverride());
		OLLMrpc.Bin.TypeOverride.register(new IconColorsOverride());
		OLLMrpc.Bin.TypeOverride.register(new ShadowOverride());
		OLLMrpc.Bin.TypeOverride.register(new EventSequenceOverride());
		OLLMrpc.Bin.TypeOverride.register(new PaintContextOverride());
		OLLMrpc.Bin.TypeOverride.register(new PaintVolumeOverride());
		OLLMrpc.Bin.TypeOverride.register(new FrameClosureOverride());
		OLLMrpc.Bin.TypeOverride.register(new MatrixEntryOverride());
		OLLMrpc.Bin.TypeOverride.register(new ShadowHelperOverride());
	}
}
