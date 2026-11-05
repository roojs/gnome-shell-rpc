clutter_rpc_build_dir = meson.current_build_dir()

clutter_deny_file = files('Clutter.deny')
clutter_overrides_file = configure_file(
  input: 'Clutter.overrides',
  output: 'Clutter.overrides',
  configuration: {
    'MUTTER_API_VERSION': mutter_api_version,
  },
)
batch_whitelist = files('batch.whitelist')
clutter_override_dir = meson.current_source_dir() / 'overrides'
clutter_override_files = files(
  'overrides/Clutter.override.vala',
  'overrides/AlignConstraint.override.vala',
  'overrides/BindConstraint.override.vala',
  'overrides/BrightnessContrastEffect.override.vala',
  'overrides/DesaturateEffect.override.vala',
  'overrides/Clone.override.vala',
  'overrides/Constraint.override.vala',
  'overrides/ActorBox.override.vala',
  'overrides/ClickAction.override.vala',
  'overrides/Actor.override.vala',
  'overrides/LayoutManager.override.vala',
  'overrides/LayoutMeta.override.vala',
  'overrides/SnapConstraint.override.vala',
  'overrides/ActorIter.override.vala',
  'overrides/PipelineNode.override.vala',
  'overrides/PaintContext.override.vala',
  'overrides/PaintNode.override.vala',
  'overrides/Transition.override.vala',
  'overrides/Interval.override.vala',
  'overrides/Text.override.vala',
  'overrides/InputDevice.override.vala',
  'overrides/InputMethod.override.vala',
  'overrides/ShaderEffect.override.vala',
  'overrides/TextureContent.override.vala',
)
if mutter_api_version == '18'
  clutter_override_files += files(
    '../libmutter-clutter-rpc-18/overrides/Stage.override.vala',
    '../libmutter-clutter-rpc-18/overrides/Backend.override.vala',
    '../libmutter-clutter-rpc-18/overrides/Gesture.override.vala',
    '../libmutter-clutter-rpc-18/overrides/ClickGesture.override.vala',
    '../libmutter-clutter-rpc-18/overrides/PanGesture.override.vala',
  )
  clutter_deny_file = files('../libmutter-clutter-rpc-18/Clutter.deny')
  clutter_override_dir = meson.current_source_dir() / '../libmutter-clutter-rpc-18/overrides' + ':' + clutter_override_dir
else
  clutter_override_files += files(
    'overrides/GestureAction.override.vala',
    'overrides/Stage.override.vala',
    'overrides/Backend.override.vala',
  )
endif
# Two single-output emits — Meson 1.7 Vala cannot compile CustomTargetIndex
# (clutter_generated[0] / [1]) as a source.
clutter_generated = custom_target('Clutter_generated.vala',
  output: 'Clutter_generated.vala',
  command: [
    gi_stub_gen,
    '--out=@OUTPUT@',
    '--missing-out=' + meson.current_build_dir() / 'Clutter_generated.missing.md',
    '--typelib-dir=' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--batch-file=' + meson.current_source_dir() / 'batch.whitelist',
    '--overrides-file=@INPUT1@',
    '--override-path=' + clutter_override_dir,
    'emit', 'Clutter', mutter_api_version,
  ],
  input: [clutter_deny_file, clutter_overrides_file, batch_whitelist] + clutter_override_files,
  depends: [gi_stub_gen],
  build_by_default: true,
)
clutter_helper_vfunc_ids = custom_target('Clutter_helper_vfunc_ids.vala',
  output: 'Clutter_helper_vfunc_ids.vala',
  command: [
    gi_stub_gen,
    '--out=' + meson.current_build_dir() / 'Clutter_generated_for_helper.vala',
    '--helper-out=@OUTPUT@',
    '--typelib-dir=' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--batch-file=' + meson.current_source_dir() / 'batch.whitelist',
    '--overrides-file=@INPUT1@',
    '--override-path=' + clutter_override_dir,
    'emit', 'Clutter', mutter_api_version,
  ],
  input: [clutter_deny_file, clutter_overrides_file, batch_whitelist] + clutter_override_files,
  depends: [gi_stub_gen],
  build_by_default: true,
)
# The Clutter emit writes this beside the stubs. Vala cannot take a
# second output of that target, so copy it to its own output.
clutter_boxed = custom_target('Clutter_boxed.vala',
  input: clutter_generated,
  output: 'Clutter_boxed.vala',
  command: [
    'cp',
    meson.current_build_dir() / 'Clutter_generated_boxed.vala',
    '@OUTPUT@',
  ],
  build_by_default: true,
)

# Gsr.Boxed is its own namespace. Shell-16 writes a GIR, and a GIR
# cannot hold a second top-level namespace, so this compiles alone.
# Absolute path: a ../ path would leave namespace.c in the same place
# as the St boxed library.
gsr_clutter_boxed_lib = static_library(
  'gsr-clutter-boxed',
  files(meson.project_source_root() / 'src' / 'boxed' / 'namespace.vala'),
  clutter_boxed,
  dependencies: [
    ocrpc_dep,
    dependency('gee-0.8'),
    dependency('graphene-gobject-1.0'),
  ] + mutter_dep,
  vala_args: mutter_vala_args + ocrpc_vala_args + [
    '--pkg=gee-0.8',
    '--pkg=graphene-gobject-1.0',
  ],
  vala_header: 'gsr-clutter-boxed.h',
  vala_vapi: 'gsr-clutter-boxed.vapi',
)

# Stub Clutter (separate from Meta — stock-like mutter-clutter split).
mutter_clutter_rpc_gir_name = 'mutter-clutter-rpc-' + mutter_api_version
# compare-clutter-headers.sh reads build/src/clutter-include/clutter.
mutter_clutter_rpc_incdir = meson.project_build_root() / 'src' / 'clutter-include'

mutter_clutter_rpc_lib = shared_library(
  'mutter-clutter-rpc-' + mutter_api_version,
  clutter_generated,
  files(
    'namespace.vala',
    meson.project_source_root() / 'src' / 'client' / 'libmutter-clutter-rpc-18' / 'Event.vala',
    meson.project_source_root() / 'src' / 'client' / 'libmutter-clutter-rpc-18' / 'EventSequence.vala',
    'Batch.vala',
    'c-clutter-abi.c',
    'c-rpc-construct-chain.c',
  ),
  dependencies: [
    mutter_vapi_dep,
    gsr_rpc_dep,
    dependency('gio-2.0'),
    dependency('cairo'),
    dependency('atk'),
    dependency('pango'),
    dependency('pangocairo'),
    dependency('graphene-gobject-1.0'),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('mutter-mtk-' + mutter_api_version),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=posix',
    '--pkg=gdesktopenums-3.0',
    '--pkg=atk',
    '--pkg=pango',
    '--pkg=pangocairo',
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--pkg=gsr-rpc-shared',
    '--vapidir', gsr_rpc_build_dir,
    '--vapidir', meson.current_source_dir(),
    '--pkg=gsr-clutter-effect-abi',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + meson.current_source_dir(),
    '-I' + gsr_rpc_build_dir,
    '-DMUTTER_CLUTTER_RPC_HEADER="mutter-clutter-rpc-' + mutter_api_version + '.h"',
  ] + mutter_clutter_cflags + mutter_clutter_stock_inc,
  vala_header: 'mutter-clutter-rpc-' + mutter_api_version + '.h',
  vala_vapi: 'mutter-clutter-rpc-' + mutter_api_version + '.vapi',
  build_rpath: ocrpc_rpath + ':' + gsr_rpc_build_dir,
  # Actor overrides write Shell.Signals symbols defined in libshell-16.
  link_args: ['-Wl,--unresolved-symbols=ignore-all'],
  install: true,
  install_rpath: mutter_typelib_dir,
)

# Generator-owned stock-shaped clutter/ tree (0.7.4).
clutter_headers_config = files('Clutter.headers')
clutter_header_override_files = files(
  'header-overrides/Event.h',
  'header-overrides/ActorBox.h',
  'header-overrides/ActorIter.h',
  'header-overrides/Actor.methods.h',
  'header-overrides/Interval.methods.h',
  'header-overrides/PaintContext.methods.h',
  'header-overrides/PaintNode.methods.h',
  'header-overrides/ShaderEffect.methods.h',
  'header-overrides/TextBuffer.h',
  'header-overrides/TextBuffer.methods.h',
  'header-overrides/clutter-keysyms.h',
  'header-overrides/clutter-macros.h',
  'header-overrides/clutter-main.h',
  'header-overrides/clutter-pango.h',
  'header-overrides/pango/clutter-actor-pango.h',
  'header-overrides/pango/clutter-text.h',
  'header-overrides/pango/clutter-text-buffer.h',
  'header-overrides/pango/clutter-text-node.h',
)
if mutter_api_version == '18'
  clutter_header_override_files += files(
    '../libmutter-clutter-rpc-18/header-overrides/Stage.methods.h',
  )
else
  clutter_header_override_files += files(
    'header-overrides/Stage.methods.h',
  )
endif
stage_clutter_headers = custom_target(
  'clutter-rpc-headers',
  output: 'clutter-headers.stamp',
  input: [clutter_headers_config] + clutter_header_override_files,
  command: [
    'sh', '-c',
    'mkdir -p "$2" && "$1" --typelib-dir="$3" --outdir="$2" --headers-config="$4" emit-headers Clutter ' + mutter_api_version + ' && touch "$5"',
    'sh',
    gi_stub_gen,
    mutter_clutter_rpc_incdir,
    mutter_typelib_dir,
    clutter_headers_config,
    '@OUTPUT@',
  ],
  depends: [gi_stub_gen],
  build_by_default: true,
)
meson.add_install_script(
  'sh', '-c',
  'mkdir -p "${DESTDIR}$2" && cp -a "$1/." "${DESTDIR}$2/"',
  'sh',
  mutter_clutter_rpc_incdir,
  get_option('prefix') / get_option('includedir') / mutter_clutter_rpc_gir_name,
)

# Link-only: Meta Vala .c uses mutter-clutter-rpc-16.h (vala_header) for Clutter*.
# Do not put clutter-include on that compile line — it fights the Vala blob.
mutter_clutter_rpc_link_dep = declare_dependency(
  link_with: mutter_clutter_rpc_lib,
  dependencies: [
    gsr_rpc_dep,
    ocrpc_dep,
    dependency('gee-0.8'),
    dependency('mutter-mtk-' + mutter_api_version),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('atk'),
    dependency('pango'),
  ],
)

# St / Shell clients: generated clutter/ tree only (0.7.4).
mutter_clutter_rpc_client_dep = declare_dependency(
  dependencies: [mutter_clutter_rpc_link_dep],
  compile_args: [
    '-I' + mutter_clutter_rpc_incdir,
    '-I' + meson.current_source_dir(),
  ] + mutter_clutter_dep_cflags,
  sources: [stage_clutter_headers],
)
