/**
 * Typelib → stub / header generator for 0.5–0.7.4 (libgirepository).
 *
 * {@link TypelibWalk} — shared deny/overrides + info walk.
 * {@link Generator} — Vala stubs.
 * {@link HeaderConfig} / {@code *.headers} — include-tree layout for emit-headers.
 * {@link HeaderGenerator} — stock-shaped {@code <subdir>/*.h} (0.7.4).
 * {@link Application} — CLI ({@code emit} / {@code emit-headers}).
 *
 * == Example ==
 *
 * {{{
 * ./build/src/gi-stub-gen --debug emit GiRpcSmoke 1.0 \
 *   --typelib-dir=./build/src --out=/tmp/out.vala
 * ./build/src/gi-stub-gen emit-headers Clutter 16 \
 *   --headers-config=src/gi-stub-gen/Clutter.headers \
 *   --typelib-dir=…/mutter-16 --outdir=./build/src/clutter-include
 * }}}
 */
namespace GnomeShellRpc.GiStubGen
{
}
