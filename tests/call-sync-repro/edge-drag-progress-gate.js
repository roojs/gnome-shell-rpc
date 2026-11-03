imports.gi.versions.EdgeDragProgressGate = '1.0';

const Gate = imports.gi.EdgeDragProgressGate;
const mode = ARGV[0];
const object = mode === 'fixed' ? new Gate.Fixed() : new Gate.Current();

object.connect('progress', () => {});
print(`edge-drag-progress-${mode}: ok`);
