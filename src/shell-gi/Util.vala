/**
 * {@code Shell.util_*} — spawn (S1) + systemd user-manager async (0.7.7 A).
 *
 * Systemd helpers mirror stock {@code shell-util.c}: session-bus
 * {@code org.freedesktop.systemd1.Manager} StartUnit / StopUnit / GetUnit.
 */
namespace Shell
{
	public GLib.Pid util_spawn_async(
		string? working_directory,
		[CCode (array_length = false, array_null_terminated = true)] string[] argv,
		[CCode (array_length = false, array_null_terminated = true)] string[]? envp,
		GLib.SpawnFlags flags
	) throws GLib.Error
	{
		GLib.Pid pid;
		GLib.Process.spawn_async(
			working_directory, argv, envp, flags, null, out pid);
		return pid;
	}

	public GLib.Pid util_spawn_async_with_fds(
		string? working_directory,
		[CCode (array_length = false, array_null_terminated = true)] string[] argv,
		[CCode (array_length = false, array_null_terminated = true)] string[]? envp,
		GLib.SpawnFlags flags,
		int stdin_fd,
		int stdout_fd,
		int stderr_fd
	) throws GLib.Error
	{
		GLib.Pid pid;
		GLib.Process.spawn_async_with_fds(
			working_directory, argv, envp, flags, null, out pid,
			stdin_fd, stdout_fd, stderr_fd);
		return pid;
	}

	public GLib.Pid util_spawn_async_with_pipes(
		string? working_directory,
		[CCode (array_length = false, array_null_terminated = true)] string[] argv,
		[CCode (array_length = false, array_null_terminated = true)] string[]? envp,
		GLib.SpawnFlags flags,
		out int standard_input,
		out int standard_output,
		out int standard_error
	) throws GLib.Error
	{
		GLib.Pid pid;
		GLib.Process.spawn_async_with_pipes(
			working_directory, argv, envp, flags, null, out pid,
			out standard_input, out standard_output, out standard_error);
		return pid;
	}

	public GLib.Pid util_spawn_async_with_pipes_and_fds(
		string? working_directory,
		[CCode (array_length = false, array_null_terminated = true)] string[] argv,
		[CCode (array_length = false, array_null_terminated = true)] string[]? envp,
		GLib.SpawnFlags flags,
		int stdin_fd,
		int stdout_fd,
		int stderr_fd,
		[CCode (array_length_type = "gsize")] int[] source_fds,
		[CCode (array_length_type = "gsize")] int[] target_fds,
		out int standard_input,
		out int standard_output,
		out int standard_error
	) throws GLib.Error
	{
		GLib.Pid pid;
		GLib.Process.spawn_async_with_pipes_and_fds(
			working_directory, argv, envp, flags, null,
			stdin_fd, stdout_fd, stderr_fd, source_fds, target_fds,
			out pid, out standard_input, out standard_output, out standard_error);
		return pid;
	}

	static async void systemd_call(
		string method,
		GLib.Variant params,
		GLib.Cancellable? cancellable
	) throws GLib.Error
	{
		var bus = yield GLib.Bus.@get(GLib.BusType.SESSION, cancellable);
		yield bus.call("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
			"org.freedesktop.systemd1.Manager", method, params, null,
			GLib.DBusCallFlags.NONE, -1, cancellable);
	}

	public async bool util_systemd_unit_exists(
		string unit,
		GLib.Cancellable? cancellable = null
	) throws GLib.Error
	{
		yield systemd_call("GetUnit", new GLib.Variant("(s)", unit), cancellable);
		return true;
	}

	public async bool util_start_systemd_unit(
		string unit,
		string mode,
		GLib.Cancellable? cancellable = null
	) throws GLib.Error
	{
		yield systemd_call("StartUnit", new GLib.Variant("(ss)", unit, mode), cancellable);
		return true;
	}

	public async bool util_stop_systemd_unit(
		string unit,
		string mode,
		GLib.Cancellable? cancellable = null
	) throws GLib.Error
	{
		yield systemd_call( "StopUnit", new GLib.Variant("(ss)", unit, mode), cancellable);
		return true;
	}

	/** Nested Wayland — no X11 display extension probe. */
	public static bool util_has_x11_display_extension( Meta.Display display, string extension )
	{
		return false;
	}

	/**
	 * Stock {@code shell_util_get_week_start} — first weekday 0=Sun…6=Sat.
	 * Copied from gtkcalendar / {@code shell-util.c} (glibc {@code nl_langinfo}).
	 */
	public int util_get_week_start()
	{
		/*
		 * glibc returns the YYYYMMDD week origin as the pointer value of
		 * nl_langinfo(_NL_TIME_WEEK_1STDAY); stock C reads it via a
		 * char* / uint union on that return.
		 */
		unowned string origin_s = Posix.NLTime.WEEK_1STDAY.to_string();
		var week_origin = (uint) (uint64) ((void*) origin_s);

		if (week_origin != 19971130 && week_origin != 19971201) {
			GLib.warning("Unknown value of _NL_TIME_WEEK_1STDAY.");
		}

		return ((week_origin == 19971201 ? 1 : 0)
			+ (int) Posix.NLTime.FIRST_WEEKDAY.to_string().data[0]
			- 1) % 7;
	}

	/**
	 * Stock {@code shell_util_translate_time_string}: look up {@code str} in
	 * the LC_MESSAGES catalogue using the locale from {@code LC_TIME}
	 * (optional {@code \\004} msgctxt via {@code g_dpgettext}).
	 *
	 * Stock uses thread-local {@code uselocale}; thin host is single-threaded
	 * GJS so {@code setlocale(LC_MESSAGES)} matches older stock and is enough.
	 */
	public unowned string util_translate_time_string(string str)
	{
		var locale = GLib.Environment.get_variable("LC_TIME");
		string? prev = null;
		if (locale != null && locale.length > 0) {
			prev = GLib.Intl.setlocale(GLib.LocaleCategory.MESSAGES, null);
			GLib.Intl.setlocale(GLib.LocaleCategory.MESSAGES, locale);
		}

		var sep = str.index_of_char((char) 4);
		var offset = sep >= 0 ? sep + 1 : 0;
		unowned string res = GLib.dpgettext(null, str, (size_t) offset);

		if (locale != null && locale.length > 0) {
			GLib.Intl.setlocale(GLib.LocaleCategory.MESSAGES, prev != null ? prev : "");
		}
		return res;
	}

	/**
	 * Stock {@code shell_util_set_hidden_from_pick} — connect {@code pick}
	 * and stop emission so the actor is skipped even under PICK_ALL.
	 */
	public void util_set_hidden_from_pick(Clutter.Actor actor, bool hidden)
	{
		const string key = "shell-stop-pick";
		if (hidden) {
			if (actor.get_data<void*>(key) != null) {
				return;
			}
			actor.pick.connect(stop_pick);
			actor.set_data(key, (void*) 0x1);
		} else {
			if (actor.get_data<void*>(key) == null) {
				return;
			}
			actor.pick.disconnect(stop_pick);
			actor.set_data(key, null);
		}
	}

	static void stop_pick(Clutter.Actor actor, Clutter.PickContext pick_context)
	{
		GLib.Signal.stop_emission_by_name(actor, "pick");
	}
}
