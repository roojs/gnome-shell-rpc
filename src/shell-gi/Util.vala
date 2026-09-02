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
		yield systemd_call(
			"StartUnit", new GLib.Variant("(ss)", unit, mode), cancellable);
		return true;
	}

	public async bool util_stop_systemd_unit(
		string unit,
		string mode,
		GLib.Cancellable? cancellable = null
	) throws GLib.Error
	{
		yield systemd_call(
			"StopUnit", new GLib.Variant("(ss)", unit, mode), cancellable);
		return true;
	}
}
