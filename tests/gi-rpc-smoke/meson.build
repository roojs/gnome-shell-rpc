# 0.5 GiRpcSmoke toy. Product nested path does not use this.
# One Vala compile. Relative paths keep each namespace.vala distinct.
# An absolute path would collapse them all to namespace.c.

girpcsmoke_typelib_schema = custom_target(
  'GiRpcSmoke-1.0-schema.typelib',
  input: files('GiRpcSmoke-1.0.gir'),
  output: 'GiRpcSmoke-1.0-schema.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libgirpcsmoke.so',
    '@INPUT@',
  ],
)

girpcsmoke_schema_dir = meson.current_build_dir() / 'gi-rpc-smoke-schema'
girpcsmoke_schema_named = custom_target(
  'GiRpcSmoke-schema-named',
  input: girpcsmoke_typelib_schema,
  output: 'gi-rpc-smoke-schema.stamp',
  command: [
    'sh', '-c',
    'mkdir -p "$1" && cp "$2" "$1/GiRpcSmoke-1.0.typelib" && touch "$3"',
    'sh',
    girpcsmoke_schema_dir,
    '@INPUT@',
    '@OUTPUT@',
  ],
)

girpcsmoke_generated = custom_target(
  'GiRpcSmoke_generated.vala',
  output: 'GiRpcSmoke_generated.vala',
  command: [
    gi_stub_gen,
    '--out=@OUTPUT@',
    '--typelib-dir=' + girpcsmoke_schema_dir,
    'emit', 'GiRpcSmoke', '1.0',
  ],
  depends: [girpcsmoke_schema_named, gi_stub_gen],
)

girpcsmoke_lib = shared_library(
  'girpcsmoke',
  girpcsmoke_generated,
  files(
    'namespace.vala',
    '../../src/client/rpc/namespace.vala',
    '../meta-mini/namespace.vala',
    '../meta-mini/Window.vala',
    '../meta-mini/WindowActor.vala',
    '../meta-mini/Context.vala',
    '../meta-mini/Display.vala',
    '../meta-mini/Compositor.vala',
    '../meta-mini/Backend.vala',
    '../meta-mini/StartupNotification.vala',
    '../meta-mini/LaunchContext.vala',
    '../meta-mini/SoundPlayer.vala',
    '../meta-mini/IdleMonitor.vala',
    '../../src/client/libmutter-rpc-16/PaintedContent.vala',
    '../../src/client/Cancellable.vala',
    '../../src/shared/namespace.vala',
    '../../src/shared/Rectangle.vala',
    '../../src/shared/ClutterEventState.vala',
    '../../src/shared/Window.vala',
    '../../src/shared/Workspace.vala',
    '../../src/server/rpc/namespace.vala',
  ),
  dependencies: [ocrpc_dep] + meta_mini_deps,
  vala_args: ocrpc_vala_args + meta_mini_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

girpcsmoke_typelib = custom_target(
  'GiRpcSmoke-1.0.typelib',
  input: files('GiRpcSmoke-1.0.gir'),
  output: 'GiRpcSmoke-1.0.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', girpcsmoke_lib.full_path(),
    '@INPUT@',
  ],
  depends: girpcsmoke_lib,
)
