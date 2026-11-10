/**
 * App indicators call {@code Gio._promisify} on
 * {@code St.IconInfo.load_symbolic_async}. The stock typelib looks
 * that C symbol up in {@code libst-rpc}. The sync load already
 * returns the pixbuf; the async call has to complete a task the
 * finish method can read.
 *
 *   meson compile -C build tests/call-sync-repro/symbolic-icon-async-gate
 *   timeout 5 ./build/tests/call-sync-repro/symbolic-icon-async-gate
 */

private class SymbolicLoad : GLib.Object {
	public Gdk.Pixbuf? pixbuf;
	public bool was_symbolic;
}

private class SymbolicIcon : GLib.Object {
	public Gdk.Pixbuf? load_sync(out bool was_symbolic) throws GLib.Error {
		was_symbolic = true;
		return new Gdk.Pixbuf(Gdk.Colorspace.RGB, false, 8, 1, 1);
	}

	public void load_symbolic_async(
		GLib.Cancellable? cancellable,
		[CCode (scope = "async")] GLib.AsyncReadyCallback? callback
	) {
		var task = new GLib.Task(this, cancellable, null);
		if (task.return_error_if_cancelled()) {
			if (callback != null) {
				callback(this, task);
			}
			return;
		}
		try {
			bool was_symbolic;
			var pixbuf = this.load_sync(out was_symbolic);
			var holder = new SymbolicLoad();
			holder.pixbuf = pixbuf;
			holder.was_symbolic = was_symbolic;
			holder.ref();
			task.set_task_data((void*) holder, unref_holder);
			task.return_boolean(true);
		} catch (GLib.Error e) {
			task.return_error(e);
		}
		if (callback != null) {
			callback(this, task);
		}
	}

	public Gdk.Pixbuf? load_symbolic_finish(GLib.AsyncResult res, out bool was_symbolic) throws GLib.Error 
	{
		was_symbolic = false;
		var task = res as GLib.Task;
		if (task == null) {
			throw new GLib.IOError.FAILED("not a Task");
		}
		if (!task.propagate_boolean()) {
			return null;
		}
		var holder = (SymbolicLoad) task.get_task_data();
		if (holder == null) {
			return null;
		}
		was_symbolic = holder.was_symbolic;
		var pixbuf = holder.pixbuf;
		holder.pixbuf = null;
		return pixbuf;
	}

	private static void unref_holder(void* data) {
		if (data != null) {
			((SymbolicLoad) data).unref();
		}
	}
}

public static int main(string[] args) {
	var icon = new SymbolicIcon();
	bool saw = false;
	string result = "miss callback-not-called";
	icon.load_symbolic_async(null, (obj, res) => {
		saw = true;
		var self = (SymbolicIcon) obj;
		try {
			bool was_symbolic;
			var pixbuf = self.load_symbolic_finish(res, out was_symbolic);
			if (pixbuf != null && pixbuf.width == 1 && was_symbolic) {
				result = "ok";
			} else {
				result = "miss pixbuf";
			}
		} catch (GLib.Error e) {
			result = "miss " + e.message;
		}
	});
	stdout.printf("symbolic-icon-async: %s\n", result);
	return saw && result == "ok" ? 0 : 1;
}
