/**
 * Minimal {@code Shell.util_*} for environment.js GLib.spawn_* wrappers (0.7.7 S1).
 *
 * Stock also resets RLIMIT_NOFILE in a child setup; we use GLib.Process only.
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
}
