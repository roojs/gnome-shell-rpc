boxed_pack_gate = executable(
  'boxed-pack-gate',
  'boxed-pack-gate.vala',
  clutter_boxed,
  dependencies: [ocrpc_dep, mutter_dep],
  vala_args: mutter_vala_args + ocrpc_vala_args + [
    '--pkg=gee-0.8',
    '--pkg=graphene-gobject-1.0',
  ],
  build_rpath: ocrpc_rpath,
  install: false,
)

test('boxed-pack-gate', boxed_pack_gate)
