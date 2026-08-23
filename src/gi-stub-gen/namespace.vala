/**
 * Typelib → stub generator for 0.5 (libgirepository, not GIR XML).
 *
 * {@link Generator} walks typelibs and emits Vala stubs.
 * {@link Application} is the CLI ({@link GLib.Application} +
 * {@link GnomeShellRpc.ApplicationInterface} for {@code --debug}).
 *
 * == Example ==
 *
 * {{{
 * ./build/src/gi-stub-gen --debug emit GiRpcSmoke 1.0 \
 *   --typelib-dir=./build/src --out=/tmp/out.vala
 * }}}
 */
namespace GnomeShellRpc.GiStubGen
{
}
