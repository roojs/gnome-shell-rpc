const namespace = ARGV[0] === 'broken'
    ? 'MetaKeymapInvokerBroken'
    : 'MetaKeymapInvokerGate';

imports.gi.versions[namespace] = '1.0';
const Meta = imports.gi[namespace];

Meta.KeymapDescription.new_from_rules(
    'pc105', 'us', '', '', ['English'], ['en']);
print(`meta-keymap-invoker-${ARGV[0]}: ok`);
