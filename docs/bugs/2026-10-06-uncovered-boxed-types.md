# Uncovered boxed types

**Status:** ⏳ open. Overrides are in the tree. The Ubuntu VM has not been given this build.

`Graphene.Size` on `notify::size` already has a `TypeOverride`. The same
`unsupported bin value type` throw remains for every other boxed GType
that is still written raw. `OLLMrpc.Gi.register` aliases objects and
interfaces only. `StreamValue` accepts a boxed GType when it is in
`gtype_to_alias` (four zero bytes) or when a `TypeOverride` has already
expanded it. Anything else throws, `Connection.write` stops the socket,
and the client logs `Unexpected early end-of-stream`.

Notify and signal arguments are the path that writes the raw boxed
GType. `Live.Subscription` calls `TypeOverride.pack` before
`StreamValue.write`. A method return or out parameter of a record goes
through `Gi.scalar`, which copies `sizeof` bytes into `GLib.Bytes`. That
return does not throw this string. The overrides below still cover those
records, so a later notify or signal argument does not drop the socket.

## Property notifies

These are the same hole as `Graphene.Size`. A layout or style notify
writes the boxed value.

| GType | Properties | Wire |
| --- | --- | --- |
| `GrapheneMatrix` | `Clutter.Actor` `transform`, `child-transform` | 16 floats, row-major, `graphene_matrix_to_float` |
| `ClutterPerspective` | `Clutter.Stage` `perspective` | fovy, aspect, z_near, z_far |
| `ClutterMargin` | `St` `fade-margins` | left, right, top, bottom |
| `CoglColor` | `background-color`, `brightness`, `contrast`, `tint`, `color`, `cursor-color`, `selected-text-color`, `selection-color`, `Shell.bg-color` | red, green, blue, alpha as 0–255 |

## Other GTypes

Packed from the public fields or getters. Opaque records pack nothing,
the same way `Clutter.PickContext` does. There is no public snapshot to
rebuild on the client.

| GType | Wire |
| --- | --- |
| `GraphenePoint3D` | x, y, z |
| `GrapheneVec2` | x, y |
| `GrapheneVec3` | x, y, z |
| `GrapheneVec4` | x, y, z, w |
| `GrapheneQuaternion` | x, y, z, w via `to_vec4` |
| `GrapheneBox` | min x/y/z, max x/y/z |
| `GrapheneEuler` | x, y, z, order |
| `GraphenePlane` | normal x/y/z, constant |
| `GrapheneRay` | origin x/y/z, direction x/y/z |
| `GrapheneSphere` | center x/y/z, radius |
| `GrapheneTriangle` | three vertices, x/y/z each |
| `GrapheneQuad` | four points, x/y each |
| `GrapheneFrustum` | six planes, each normal x/y/z plus constant |
| `StIconColors` | four colors, each red/green/blue/alpha |
| `StShadow` | color, xoffset, yoffset, blur, spread, inset |
| `ClutterEventSequence` | empty. Public data is `get_slot` only, and the client stub does not store a slot. |
| `ClutterPaintContext` | empty |
| `ClutterPaintVolume` | empty. The client stub is an object, so a volume snapshot has nowhere to land. |
| `CoglFrameClosure` | empty |
| `CoglMatrixEntry` | empty. `cogl_matrix_entry_get` can read a matrix; nothing public builds an entry back. |
| `StShadowHelper` | empty |

Server pack is `Gsr.Server.Clutter` and `Gsr.Server.St`. Client unpack is
`Shell`, registered from `Shell.register()`.

## Not a StreamValue GType

These do not get a `TypeOverride`. `StreamValue` is not handed the name.

No `glib:type-name` in the GIR: `Clutter.Colorimetry`, `Clutter.EOTF`,
`Clutter.Luminance`, `Cogl.DepthState`.

Disguised records: `Cogl.DmaBufHandle`, `Cogl.TimestampQuery`,
`Meta.Group`, `Meta.Settings`.

## What not to do

Do not `Bin.register` these so the payload becomes four zero bytes. A
property getter on the client reads `GLib.Bytes` of the native struct
from `Gi.scalar`. An alias with an empty payload replaces that copy.

Do not invent GTypes for the four records that have none.
