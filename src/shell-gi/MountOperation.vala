/**
 * Owned {@code Shell.MountOperation} — stock {@code shell-mount-operation.c}.
 *
 * Dummy {@link GLib.MountOperation} subclass: default GIO idle-replies
 * UNHANDLED; we swallow ask-password / ask-question / show-processes so JS
 * can reply. {@link show_processes_2} + getters forward process arrays
 * that GJS cannot take from the stock signal yet.
 */
namespace Shell
{
	public class MountOperation : GLib.MountOperation
	{
		private GLib.Array<GLib.Pid>? pids;
		private string[]? choices;
		private string? message;

		public signal void show_processes_2();

		public MountOperation()
		{
			Object();
		}

		public GLib.Array<GLib.Pid>? get_show_processes_pids()
		{
			return this.pids;
		}

		public string[]? get_show_processes_choices()
		{
			return this.choices;
		}

		public string? get_show_processes_message()
		{
			return this.message;
		}

		public override void ask_password(
			string message,
			string default_user,
			string default_domain,
			GLib.AskPasswordFlags flags
		)
		{
			/* Swallow — JS owns ask-password via the base signal. */
		}

		public override void ask_question(string message, string[] choices)
		{
			/* Swallow — JS owns ask-question. */
		}

		public override void show_processes(
			string message,
			GLib.Array<GLib.Pid> processes,
			string[] choices
		)
		{
			this.pids = processes;
			this.choices = choices;
			this.message = message;
			this.show_processes_2();
		}
	}
}
