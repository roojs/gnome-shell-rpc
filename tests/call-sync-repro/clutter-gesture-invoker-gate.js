const namespace = ARGV[0] === 'broken'
    ? 'ClutterGestureInvokerBroken'
    : 'ClutterGestureInvokerGate';

imports.gi.versions[namespace] = '1.0';
const Clutter = imports.gi[namespace];

const gesture = new Clutter.Gesture();
gesture.get_point_event(7);
print(`clutter-gesture-invoker-${ARGV[0]}: ok`);
