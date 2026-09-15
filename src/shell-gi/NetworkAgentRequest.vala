/**
 * In-flight secret request for {@link NetworkAgent}.
 */
namespace Shell
{
	internal class NetworkAgentRequest
	{
		public NetworkAgent agent;
		public GLib.Cancellable cancellable {
			get; set;
			default = new GLib.Cancellable();
		}
		public string request_id;
		public NM.Connection connection;
		public string setting_name;
		public string[] hints;
		public NM.SecretAgentGetSecretsFlags flags;
		public NM.SecretAgentOldGetSecretsFunc callback;
		public GLib.VariantDict? entries;
		public GLib.VariantBuilder vpn_builder {
			get; set;
			default = new GLib.VariantBuilder(new GLib.VariantType("a{ss}"));
		}

		public NetworkAgentRequest(
			NetworkAgent agent,
			string request_id,
			NM.Connection connection,
			string setting_name,
			string[] hints,
			NM.SecretAgentGetSecretsFlags flags,
			owned NM.SecretAgentOldGetSecretsFunc callback
		) {
			this.agent = agent;
			this.request_id = request_id;
			this.connection = connection;
			this.setting_name = setting_name;
			this.hints = hints;
			this.flags = flags;
			this.callback = (owned) callback;
		}

		public void cancel()
		{
			var error = new NM.SecretAgentError.AGENTCANCELED("Canceled by NetworkManager");
			this.callback(this.agent, this.connection, null, error);
			this.agent.cancel_request(this.request_id);
			this.agent.requests.unset(this.request_id);
		}

		public void ask_ui()
		{
			this.agent.new_request(this.request_id, this.connection, this.setting_name,
				this.hints, (int) this.flags);
		}
	}
}
