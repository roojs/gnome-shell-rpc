imports.gi.versions.PolkitInitiateShape = '1.0';

const Shape = imports.gi.PolkitInitiateShape;
const mode = ARGV[0];

if (mode !== 'length' && mode !== 'strv') {
	print('FAIL polkit-initiate-shape: mode ' + mode);
	imports.system.exit(1);
}

const agent = mode === 'length' ? new Shape.LengthAgent() : new Shape.StrvAgent();
let names = null;
agent.connect('initiate', (_obj, _actionId, _message, _iconName, _cookie, userNames) => {
	names = userNames;
});
agent.fire();

if (mode === 'length') {
	print('FAIL polkit-initiate-shape: length signal returned to JS');
	imports.system.exit(1);
}
if (names === null || names.length !== 1 || names[0] !== 'alan') {
	print('FAIL polkit-initiate-shape: strv names=' + names);
	imports.system.exit(1);
}
print('PASS polkit-initiate-shape: strv user_names=[alan]');
