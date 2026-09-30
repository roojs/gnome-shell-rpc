/**
 * Owned {@code Shell.KeyringPrompt} — stock {@code shell-keyring-prompt.c}.
 *
 * {@link Gcr.Prompt} that drives the keyring JS UI via
 * {@link show_password} / {@link show_confirm}, with password fields
 * backed by {@link SecureTextBuffer}.
 */
namespace Shell
{
	public class KeyringPrompt : GLib.Object, Gcr.Prompt
	{
		private enum Mode
		{
			NONE,
			CONFIRM,
			PASSWORD
		}

		private Mode mode = Mode.NONE;
		private bool shown;
		private string? reply_password;
		private Gcr.PromptReply reply_confirm;
		private ulong password_changed_id;

		private string priv_continue_label = "";
		private string priv_cancel_label = "";
		private string priv_warning = "";
		private string priv_choice_label = "";
		private bool priv_password_new;
		private int priv_password_strength;
		private Clutter.Text? priv_password_actor;
		private Clutter.Text? priv_confirm_actor;

		public signal void show_password();
		public signal void show_confirm();
		public signal void answered();

		public string title { owned get; set construct; default = ""; }
		public string message { owned get; set construct; default = ""; }
		public string description { owned get; set construct; default = ""; }
		public string caller_window { owned get; set construct; default = ""; }
		public bool choice_chosen { get; set; default = false; }

		public string continue_label {
			owned get {
				return this.priv_continue_label;
			}
			set construct {
				this.priv_continue_label = (value != null ? value : "").replace("_", "");
				this.notify_property("continue-label");
			}
		}

		public string cancel_label {
			owned get {
				return this.priv_cancel_label;
			}
			set construct {
				this.priv_cancel_label = (value != null ? value : "").replace("_", "");
				this.notify_property("cancel-label");
			}
		}

		public string warning {
			owned get {
				return this.priv_warning;
			}
			set construct {
				this.priv_warning = value != null ? value : "";
				this.notify_property("warning");
				this.notify_property("warning-visible");
			}
		}

		public string choice_label {
			owned get {
				return this.priv_choice_label;
			}
			set construct {
				this.priv_choice_label = (value != null ? value : "").replace("_", "");
				this.notify_property("choice-label");
				this.notify_property("choice-visible");
			}
		}

		public bool password_new {
			get {
				return this.priv_password_new;
			}
			set {
				this.priv_password_new = value;
				this.notify_property("password-new");
				this.notify_property("confirm-visible");
			}
		}

		public int password_strength {
			get {
				return this.priv_password_strength;
			}
		}

		public bool password_visible {
			get {
				return this.mode == Mode.PASSWORD;
			}
		}

		public bool confirm_visible {
			get {
				return this.priv_password_new && this.mode == Mode.PASSWORD;
			}
		}

		public bool warning_visible {
			get {
				return this.priv_warning.length > 0;
			}
		}

		public bool choice_visible {
			get {
				return this.priv_choice_label.length > 0;
			}
		}

		public Clutter.Text? password_actor {
			get {
				return this.priv_password_actor;
			}
			set {
				if (this.priv_password_actor == value) {
					return;
				}
				if (this.priv_password_actor != null) {
					this.priv_password_actor.disconnect(this.password_changed_id);
					this.password_changed_id = 0;
				}
				this.priv_password_actor = value;
				if (value != null) {
					value.buffer = new SecureTextBuffer();
					this.password_changed_id = value.signal_text_changed.connect(() => {
						this.score_password(value.text);
					});
				}
				this.notify_property("password-actor");
			}
		}

		public Clutter.Text? confirm_actor {
			get {
				return this.priv_confirm_actor;
			}
			set {
				if (this.priv_confirm_actor == value) {
					return;
				}
				this.priv_confirm_actor = value;
				if (value != null) {
					value.buffer = new SecureTextBuffer();
				}
				this.notify_property("confirm-actor");
			}
		}

		public KeyringPrompt()
		{
			Object();
		}

		public override void dispose()
		{
			if (this.shown) {
				this.close();
			}
			if (this.mode != Mode.NONE) {
				this.cancel();
			}
			this.password_actor = null;
			this.confirm_actor = null;
			base.dispose();
		}

		public override void prompt_close()
		{
			this.shown = false;
		}

		public async unowned string password_async(
			GLib.Cancellable? cancellable
		) throws GLib.Error {
			if (this.mode != Mode.NONE) {
				GLib.warning("this prompt can only show one prompt at a time");
				return "";
			}

			this.mode = Mode.PASSWORD;
			this.notify_property("password-visible");
			this.notify_property("confirm-visible");
			this.notify_property("warning-visible");
			this.notify_property("choice-visible");
			this.shown = true;
			this.show_password();

			var hid = this.answered.connect(() => {
				password_async.callback();
			});
			yield;
			this.disconnect(hid);
			return this.reply_password != null ? this.reply_password : "";
		}

		public async Gcr.PromptReply confirm_async(
			GLib.Cancellable? cancellable
		) throws GLib.Error {
			if (this.mode != Mode.NONE) {
				GLib.warning("this prompt is already prompting");
				return Gcr.PromptReply.CANCEL;
			}

			this.mode = Mode.CONFIRM;
			this.notify_property("password-visible");
			this.notify_property("confirm-visible");
			this.notify_property("warning-visible");
			this.notify_property("choice-visible");
			this.shown = true;
			this.show_confirm();

			var hid = this.answered.connect(() => {
				confirm_async.callback();
			});
			yield;
			this.disconnect(hid);
			return this.reply_confirm;
		}

		public bool complete()
		{
			return_val_if_fail(this.mode != Mode.NONE, false);
			return_val_if_fail(this.priv_password_actor != null, false);

			if (this.mode != Mode.PASSWORD) {
				this.reply_confirm = Gcr.PromptReply.CONTINUE;
				this.mode = Mode.NONE;
				this.answered();
				return true;
			}

			var password = this.priv_password_actor.text;
			if (this.priv_password_new) {
				return_val_if_fail(this.priv_confirm_actor != null, false);
				if (password != this.priv_confirm_actor.text) {
					this.warning = _("Passwords do not match");
					return false;
				}
				var env = GLib.Environment.get_variable("GNOME_KEYRING_PARANOID");
				if (env != null && env.length > 0 && password.length == 0) {
					this.warning = _("Password cannot be blank");
					return false;
				}
			}
			this.score_password(password);
			this.reply_password = password;
			this.mode = Mode.NONE;
			this.answered();
			return true;
		}

		public void cancel()
		{
			if (this.mode == Mode.NONE) {
				if (this.shown) {
					this.close();
				}
				return;
			}

			switch (this.mode) {
				case Mode.CONFIRM:
					this.reply_confirm = Gcr.PromptReply.CANCEL;
					break;

				case Mode.PASSWORD:
					this.reply_password = null;
					break;

				case Mode.NONE:
					break;
			}
			this.mode = Mode.NONE;
			this.answered();
		}

		private void score_password(string password)
		{
			if (password.length == 0) {
				this.priv_password_strength = 0;
				this.notify_property("password-strength");
				return;
			}
			var digit = /[^0-9]/.replace(password, -1, 0, "").length,
				lower = /[^a-z]/.replace(password, -1, 0, "").length,
				upper = /[^A-Z]/.replace(password, -1, 0, "").length;
			this.priv_password_strength = (int) double.min(10.0, double.max(1.0,
				int.min(password.length, 5) - 2
				+ int.min(digit, 3)
				+ int.min(password.length - digit - lower - upper, 3) * 1.5
				+ int.min(upper, 3)));
			this.notify_property("password-strength");
		}
	}
}
