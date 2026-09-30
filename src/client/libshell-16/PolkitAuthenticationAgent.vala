/**
 * Owned {@code Shell.PolkitAuthenticationAgent} — stock
 * {@code shell-polkit-authentication-agent.c}.
 *
 * {@link PolkitAgent.Listener} that queues auth requests, emits
 * {@link initiate} / {@link cancel} for the JS dialog, and completes via
 * {@link complete}.
 */
namespace Shell
{
	public class PolkitAuthenticationAgent : PolkitAgent.Listener
	{
		/**
		 * One in-flight auth dialog — stock {@code AuthRequest}.
		 *
		 * Constructor wires identities + cancellable; {@link initiate} /
		 * {@link finish} own the request-side work. {@link finished} resumes
		 * the agent's async {@link initiate_authentication}.
		 */
		private class AuthRequest
		{
			public weak PolkitAuthenticationAgent agent { get; private set; }
			public string action_id { get; private set; }
			public string message { get; private set; }
			public string icon_name { get; private set; }
			public Polkit.Details details { get; private set; }
			public string cookie { get; private set; }
			public bool dismissed { get; private set; }

			private Gee.ArrayList<Polkit.Identity> identities {
				get; set; default = new Gee.ArrayList<Polkit.Identity>();
			}
			private GLib.Cancellable? cancellable;
			private ulong handler_id;

			public signal void finished();

			public AuthRequest(
				PolkitAuthenticationAgent agent,
				string action_id,
				string message,
				string icon_name,
				Polkit.Details details,
				string cookie,
				GLib.List<Polkit.Identity> identities,
				GLib.Cancellable? cancellable
			) {
				this.agent = agent;
				this.action_id = action_id;
				this.message = message;
				this.icon_name = icon_name;
				this.details = details;
				this.cookie = cookie;
				this.cancellable = cancellable;

				foreach (var identity in identities) {
					this.identities.add(identity);
				}

				if (cancellable == null) {
					return;
				}

				this.handler_id = cancellable.connect(() => {
					/* Idle — avoid GCancellable deadlock (GNOME #642968). */
					Idle.add(() => {
						if (this == this.agent.current_request) {
							this.agent.cancel();
							return Source.REMOVE;
						}
						this.finish(false);
						return Source.REMOVE;
					});
				});
			}

			public void initiate()
			{
				string[] user_names = {};
				foreach (var identity in this.identities) {
					var user = identity as Polkit.UnixUser;
					if (user == null) {
						GLib.warning("Unsupported identity of GType %s",
							identity.get_type().name());
						continue;
					}
					unowned var pwd = Posix.getpwuid((Posix.uid_t) user.get_uid());
					if (pwd == null || pwd.pw_name == null) {
						GLib.warning("Error looking up user name for uid %d",
							user.get_uid());
						continue;
					}
					if (!((string) pwd.pw_name).validate()) {
						GLib.warning("Invalid UTF-8 in username for uid %d. Skipping",
							user.get_uid());
						continue;
					}
					user_names += pwd.pw_name;
				}

				this.agent.initiate(this.action_id, this.message,
					this.icon_name, this.cookie, user_names);
			}

			public void finish(bool dismissed)
			{
				var is_current = this == this.agent.current_request;
				if (!is_current) {
					this.agent.scheduled_requests.remove(this);
				}
				if (is_current) {
					this.agent.current_request = null;
				}

				if (this.cancellable != null && this.handler_id != 0) {
					this.cancellable.disconnect(this.handler_id);
					this.handler_id = 0;
				}

				this.dismissed = dismissed;
				this.finished();
				this.identities.clear();

				if (!is_current) {
					return;
				}
				if (this.agent.current_request != null || this.agent.scheduled_requests.size == 0) {
					return;
				}
				this.agent.current_request = this.agent.scheduled_requests.get(0);
				this.agent.scheduled_requests.remove_at(0);
				this.agent.current_request.initiate();
			}

			public void dismiss()
			{
				this.finish(true);
			}
		}

		/* Nullable object_path — stock passes NULL for the default path. */
		[CCode (cname = "polkit_agent_listener_register")]
		private static extern void* listener_register(
			PolkitAgent.Listener listener,
			PolkitAgent.RegisterFlags flags,
			Polkit.Subject subject,
			string? object_path,
			GLib.Cancellable? cancellable
		) throws GLib.Error;

		private Gee.ArrayList<AuthRequest> scheduled_requests {
			get; set; default = new Gee.ArrayList<AuthRequest>();
		}
		private AuthRequest? current_request;
		private void* handle;

		public signal void cancel();
		public signal void initiate(
			string action_id,
			string message,
			string icon_name,
			string cookie,
			string[] user_names
		);

		public PolkitAuthenticationAgent()
		{
			Object();
		}

		public override void dispose()
		{
			this.unregister();
			base.dispose();
		}

		public new void register() throws GLib.Error
		{
			var subject = new Polkit.UnixSession.for_process_sync(
				(int) Posix.getpid());
			this.handle = listener_register(this,
				PolkitAgent.RegisterFlags.NONE, subject, null, null);
		}

		public new void unregister()
		{
			while (this.scheduled_requests.size > 0) {
				this.scheduled_requests.get(0).dismiss();
			}
			if (this.current_request != null) {
				this.current_request.dismiss();
			}

			if (this.handle != null) {
				PolkitAgent.Listener.unregister(this.handle);
				this.handle = null;
			}
		}

		public void complete(bool dismissed)
		{
			return_if_fail(this.current_request != null);
			this.current_request.finish(dismissed);
		}

		public override async bool initiate_authentication(
			string action_id,
			string message,
			string icon_name,
			Polkit.Details details,
			string cookie,
			GLib.List<Polkit.Identity> identities,
			GLib.Cancellable? cancellable = null
		) throws GLib.Error {
			var request = new AuthRequest(this, action_id, message, icon_name,
				details, cookie, identities, cancellable);
			request.finished.connect(() => {
				initiate_authentication.callback();
			});

			this.scheduled_requests.add(request);
			if (this.current_request == null && this.scheduled_requests.size > 0) {
				this.current_request = this.scheduled_requests.get(0);
				this.scheduled_requests.remove_at(0);
				this.current_request.initiate();
			}
			yield;

			if (request.dismissed) {
				throw new Polkit.Error.CANCELLED("Authentication dialog was dismissed by the user");
			}
			return true;
		}
	}
}
