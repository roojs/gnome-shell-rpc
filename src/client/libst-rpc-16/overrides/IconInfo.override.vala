	private class SymbolicLoad : GLib.Object {
		public Gdk.Pixbuf? pixbuf;
		public bool was_symbolic;
	}

	/**
	 * Stock {@code st_icon_info_load_symbolic_async}. The typelib
	 * looks this symbol up in libst-rpc. {@link load_symbolic} is
	 * the RPC. The task carries that pixbuf to
	 * {@link load_symbolic_finish}.
	 */
	public void load_symbolic_async(
		IconColors colors,
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
			var pixbuf = this.load_symbolic(colors, out was_symbolic);
			var holder = new SymbolicLoad();
			holder.pixbuf = pixbuf;
			holder.was_symbolic = was_symbolic;
			holder.ref();
			task.set_task_data((void*) holder, unref_symbolic_load);
			task.return_boolean(true);
		} catch (GLib.Error e) {
			task.return_error(e);
		}
		if (callback != null) {
			callback(this, task);
		}
	}

	/**
	 * Stock {@code st_icon_info_load_symbolic_finish}.
	 * {@code Gio._promisify} calls this after
	 * {@link load_symbolic_async}.
	 */
	public Gdk.Pixbuf? load_symbolic_finish(
		GLib.AsyncResult res,
		out bool was_symbolic
	) throws GLib.Error {
		was_symbolic = false;
		var task = res as GLib.Task;
		if (task == null) {
			throw new GLib.IOError.FAILED(
				"St.IconInfo.load_symbolic_finish: not a Task");
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

	private static void unref_symbolic_load(void* data) {
		if (data != null) {
			((SymbolicLoad) data).unref();
		}
	}
