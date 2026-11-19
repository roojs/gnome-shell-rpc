/**
 * Shrink reproduction for iconGrid.js:1262
 * `TypeError: can't access property "column_spacing", this.layout_manager is null`
 *
 * Pass: icon-grid-style: ok
 * Fail: icon-grid-style: miss <reason>
 */

function meta_version() {
	try {
		imports.gi.versions.Meta = '18';
		void imports.gi.Meta;
		return '18';
	} catch (e) {
		imports.gi.versions.Meta = '16';
		return '16';
	}
}
imports.gi.versions.Meta = meta_version();
imports.gi.versions.Clutter = imports.gi.versions.Meta;
imports.gi.versions.St = imports.gi.versions.Meta;
imports.gi.versions.Shell = imports.gi.versions.Meta;

const { GLib, GObject, Clutter, St, Shell } = imports.gi;

function note(message) {
	console.log('icon-grid-style: ' + message);
}

const TestLayout = GObject.registerClass(
class TestLayout extends Clutter.LayoutManager {
	vfunc_get_preferred_width(_container, _forHeight) { return [0, 0]; }
	vfunc_get_preferred_height(_container, _forWidth) { return [0, 0]; }
	vfunc_allocate(_container, _box) {}
});

let styleChangedCalls = 0;
let nullLayoutCalls = 0;

const TestGrid = GObject.registerClass({
	Signals: { 'pages-changed': {} },
}, class TestGrid extends St.Viewport {
	_init() {
		const layoutManager = new TestLayout();
		super._init({
			style_class: 'icon-grid',
			layoutManager,
			x_expand: true,
			y_expand: true,
		});
	}

	vfunc_style_changed() {
		styleChangedCalls++;
		const hasLm = this.layout_manager != null;
		if (!hasLm)
			nullLayoutCalls++;
		note('TestGrid.vfunc_style_changed call=' + styleChangedCalls
			+ ' hasLm=' + hasLm + ' mapped=' + this.mapped);
		super.vfunc_style_changed();
	}
});

const TestAppGrid = GObject.registerClass({
	Properties: {
		'indicators-padding': GObject.ParamSpec.boxed('indicators-padding',
			null, null, GObject.ParamFlags.READWRITE, Clutter.Margin.$gtype),
	},
}, class TestAppGrid extends TestGrid {
	_init() {
		super._init();
		this._indicatorsPadding = new Clutter.Margin();
	}

	vfunc_style_changed() {
		super.vfunc_style_changed();
	}
});

const TestFolderGrid = GObject.registerClass(
class TestFolderGrid extends TestAppGrid {
	_init() {
		super._init();
	}
});

function main() {
	note('begin');
	const g = Shell.Global.get();
	const stage = g.stage;
	const ctx = St.ThemeContext.get_for_stage(stage);
	note('themeContext=' + (ctx != null));

	// Case 1: construct standalone FolderGrid
	const f1 = new TestFolderGrid();
	note('case1 calls=' + styleChangedCalls + ' nullLm=' + nullLayoutCalls);

	// Case 2: map a grid, then construct another FolderGrid while mapped / after unmap
	const box = new St.BoxLayout();
	stage.add_child(box);
	box.add_child(f1);
	note('case2-mapped calls=' + styleChangedCalls + ' nullLm=' + nullLayoutCalls);

	const f2 = new TestFolderGrid();
	note('case2-new-while-mapped calls=' + styleChangedCalls + ' nullLm=' + nullLayoutCalls);

	// Case 3: emit style-changed on stage/theme, then construct FolderGrid
	box.hide();
	const f3 = new TestFolderGrid();
	note('case3-after-hide calls=' + styleChangedCalls + ' nullLm=' + nullLayoutCalls);

	// Case 4: destroy f1 (frees rpc_lid?) then construct f4
	f1.destroy();
	const f4 = new TestFolderGrid();
	note('case4-after-destroy calls=' + styleChangedCalls + ' nullLm=' + nullLayoutCalls);

	// Case 5: construct inside a BoxLayout with style_class already set, or after set_style
	const w = new St.Widget({ style_class: 'overview-tile' });
	w.set_style('color: red;');
	const f5 = new TestFolderGrid();
	note('case5-after-set-style calls=' + styleChangedCalls + ' nullLm=' + nullLayoutCalls);

	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		note('settled calls=' + styleChangedCalls + ' nullLm=' + nullLayoutCalls);
		if (nullLayoutCalls > 0)
			note('miss null-layout-manager');
		else
			note('ok');
		f2.destroy();
		f3.destroy();
		f4.destroy();
		f5.destroy();
		w.destroy();
		box.destroy();
		loop.quit();
		g.context.terminate();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
