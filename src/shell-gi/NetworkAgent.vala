/**
 * Owned {@code Shell.NetworkAgent} — stock {@code shell-network-agent.c}.
 *
 * {@link NM.SecretAgentOld} that loads agent-owned secrets from libsecret,
 * emits {@link new_request} / {@link cancel_request} for the JS UI, and
 * saves confirmed secrets back to the keyring.
 */
namespace Shell
{
	public class NetworkAgent : NM.SecretAgentOld
	{
		internal const string KEYRING_UUID_TAG = "connection-uuid";
		internal const string KEYRING_SN_TAG = "setting-name";
		internal const string KEYRING_SK_TAG = "setting-key";

		[CCode (cname = "nm_setting_get_secret_flags")]
		internal static extern bool nm_get_secret_flags(
			NM.Setting setting,
			string secret_name,
			out NM.SettingSecretFlags out_flags
		) throws GLib.Error;

		/* Public NM APIs omit connection_path; the libnm.vapi virtuals do not. */
		[CCode (cname = "nm_secret_agent_old_save_secrets")]
		private static extern void nm_agent_save_secrets(
			NM.SecretAgentOld agent,
			NM.Connection connection,
			[CCode (scope = "async")] NM.SecretAgentOldSaveSecretsFunc? callback
		);

		[CCode (cname = "nm_secret_agent_old_delete_secrets")]
		private static extern void nm_agent_delete_secrets(
			NM.SecretAgentOld agent,
			NM.Connection connection,
			[CCode (scope = "async")] NM.SecretAgentOldDeleteSecretsFunc callback
		);

		internal Secret.Schema schema {
			get; set;
			default = new Secret.Schema(
				"org.freedesktop.NetworkManager.Connection",
				Secret.SchemaFlags.DONT_MATCH_NAME,
				KEYRING_UUID_TAG, Secret.SchemaAttributeType.STRING,
				KEYRING_SN_TAG, Secret.SchemaAttributeType.STRING,
				KEYRING_SK_TAG, Secret.SchemaAttributeType.STRING,
				null);
		}
		internal Gee.HashMap<string, NetworkAgentRequest> requests {
			get; set;
			default = new Gee.HashMap<string, NetworkAgentRequest>();
		}

		public bool force_always_ask { get; construct; default = false; }

		public signal void new_request(
			string request_id,
			NM.Connection connection,
			string setting_name,
			string[] hints,
			int flags
		);
		public signal void cancel_request(string request_id);

		public override void dispose()
		{
			var error = new NM.SecretAgentError.AGENTCANCELED("The secret agent is going away");
			foreach (var request_id in this.requests.keys.to_array()) {
				var request = this.requests.get(request_id);
				request.callback(this, request.connection, null, error);
			}
			this.requests.clear();
			base.dispose();
		}

		public void add_vpn_secret(string request_id, string setting_key, string setting_value)
		{
			var request = this.requests.get(request_id);
			request.vpn_builder.add("{ss}", setting_key, setting_value);
		}

		public void set_password(string request_id, string setting_key, string setting_value)
		{
			var request = this.requests.get(request_id);
			request.entries.insert(setting_key, "s", setting_value);
		}

		public void respond(string request_id, NetworkAgentResponse response)
		{
			var request = this.requests.get(request_id);
			switch (response) {
				case NetworkAgentResponse.USER_CANCELED:
					var user_err = new NM.SecretAgentError.USERCANCELED("Network dialog was canceled by the user");
					request.callback(this, request.connection, null, user_err);
					this.requests.unset(request_id);
					return;

				case NetworkAgentResponse.INTERNAL_ERROR:
					var internal_err = new NM.SecretAgentError.FAILED("An internal error occurred while processing the request.");
					request.callback(this, request.connection, null, internal_err);
					this.requests.unset(request_id);
					return;

				case NetworkAgentResponse.CONFIRMED:
					break;
			}

			var vpn_secrets = request.vpn_builder.end();
			if (vpn_secrets.n_children() > 0) {
				request.entries.insert_value(NM.SettingVpn.SECRETS, vpn_secrets);
			}

			var setting = request.entries.end();
			if ((request.flags & NM.SecretAgentGetSecretsFlags.ALLOW_INTERACTION) != 0
					|| (request.flags & NM.SecretAgentGetSecretsFlags.REQUEST_NEW) != 0) {
				var dup = NM.SimpleConnection.new_clone(request.connection);
				try {
					dup.update_secrets(request.setting_name, setting);
				} catch (GLib.Error e) {
				}
				NetworkAgent.nm_agent_save_secrets(this, dup, null);
			}

			var connection_builder = new GLib.VariantBuilder(new GLib.VariantType("a{sa{sv}}"));
			connection_builder.add("{s@a{sv}}", request.setting_name, setting);
			request.callback(this, request.connection, connection_builder.end(), null);
			this.requests.unset(request_id);
		}

		public async NM.VpnPluginInfo search_vpn_plugin(string service) throws GLib.Error
		{
			NM.VpnPluginInfo? info = null;
			GLib.Error? thread_error = null;
			GLib.Mutex mutex = GLib.Mutex();
			GLib.Cond cond = GLib.Cond();
			var done = false;
			new GLib.Thread<void*>("gsr-vpn-plugin", () => {
				info = new NM.VpnPluginInfo.search_file(null, service);
				if (info == null) {
					thread_error = new GLib.IOError.NOT_FOUND("No plugin for %s", service);
				}
				mutex.lock();
				done = true;
				cond.signal();
				mutex.unlock();
				return null;
			});
			mutex.lock();
			while (!done) {
				cond.wait(mutex);
			}
			mutex.unlock();
			if (thread_error != null) {
				throw thread_error;
			}
			return info;
		}

		public override void get_secrets(
			NM.Connection connection,
			string connection_path,
			string setting_name,
			string[] hints,
			NM.SecretAgentGetSecretsFlags flags,
			owned NM.SecretAgentOldGetSecretsFunc callback
		) {
			var request_id = "%s/%s".printf(connection_path, setting_name);
			if (this.requests.has_key(request_id)) {
				this.requests.get(request_id).cancel();
			}

			var request = new NetworkAgentRequest(this, request_id, connection,
				setting_name, hints, flags, (owned) callback);
			this.requests.set(request_id, request);

			if ((flags & NM.SecretAgentGetSecretsFlags.REQUEST_NEW) != 0
					|| ((flags & NM.SecretAgentGetSecretsFlags.ALLOW_INTERACTION) != 0
						&& (this.force_always_ask || this.connection_always_ask(connection)))) {
				request.entries = new GLib.VariantDict(null);
				request.ask_ui();
				return;
			}

			var attributes = new GLib.HashTable<string, string>(GLib.str_hash, GLib.str_equal);
			attributes.set(KEYRING_UUID_TAG, connection.get_uuid());
			attributes.set(KEYRING_SN_TAG, setting_name);

			Secret.password_searchv.begin(this.schema, attributes,
				Secret.SearchFlags.ALL | Secret.SearchFlags.UNLOCK | Secret.SearchFlags.LOAD_SECRETS,
				request.cancellable, (obj, res) => {
					this.finish_keyring_search(request, res);
				});
		}

		public override void cancel_get_secrets(string connection_path, string setting_name)
		{
			var request_id = "%s/%s".printf(connection_path, setting_name);
			if (!this.requests.has_key(request_id)) {
				return;
			}
			this.requests.get(request_id).cancel();
		}

		public override void save_secrets(
			NM.Connection connection,
			string connection_path,
			owned NM.SecretAgentOldSaveSecretsFunc callback
		) {
			var job = new NetworkAgentKeyringSave(this, connection, (owned) callback);
			NetworkAgent.nm_agent_delete_secrets(this, connection, (agent, conn, error) => {
				job.write_all();
			});
		}

		public override void delete_secrets(
			NM.Connection connection,
			string connection_path,
			owned NM.SecretAgentOldDeleteSecretsFunc callback
		) {
			var uuid = connection.get_uuid();
			Secret.password_clear.begin(this.schema, null, (obj, res) => {
				GLib.Error? error = null;
				try {
					Secret.password_clear.end(res);
				} catch (GLib.Error e) {
					error = new NM.SecretAgentError.FAILED("The request could not be completed.  Keyring result: %s",
						e.message);
				}
				callback(this, connection, error);
			}, KEYRING_UUID_TAG, uuid, null);
		}

		private void finish_keyring_search(NetworkAgentRequest request, GLib.AsyncResult res)
		{
			GLib.List<Secret.Retrievable> items;
			try {
				items = Secret.password_searchv.end(res);
			} catch (GLib.Error e) {
				if (e.matches(GLib.IOError.quark(), GLib.IOError.CANCELLED)) {
					return;
				}
				var error = new NM.SecretAgentError.FAILED("Internal error while retrieving secrets from the keyring (%s)",
					e.message);
				request.callback(this, request.connection, null, error);
				this.requests.unset(request.request_id);
				return;
			}

			var setting_builder = new GLib.VariantBuilder(GLib.VariantType.VARDICT);
			var secrets_found = false;
			foreach (var retrievable in items) {
				var item = retrievable as Secret.Item;
				if (item == null) {
					continue;
				}
				/* Unlock denied → null, same as stock secret_item_get_secret. */
				var secret = item.get_secret();
				if (secret == null) {
					continue;
				}
				var attributes = item.get_attributes();
				var sk = attributes.get(KEYRING_SK_TAG);
				if (sk == null) {
					continue;
				}
				setting_builder.add("{sv}", sk, new GLib.Variant.string(secret.get_text()));
				secrets_found = true;
			}

			var setting = setting_builder.end();
			if (request.setting_name == NM.SettingVpn.SETTING_NAME
					|| (!secrets_found && (request.flags & NM.SecretAgentGetSecretsFlags.ALLOW_INTERACTION) != 0)) {
				try {
					request.connection.update_secrets(request.setting_name, setting);
				} catch (GLib.Error e) {
				}
				request.entries = new GLib.VariantDict(setting);
				request.ask_ui();
				return;
			}

			var connection_builder = new GLib.VariantBuilder(new GLib.VariantType("a{sa{sv}}"));
			connection_builder.add("{s@a{sv}}", request.setting_name, setting);
			request.callback(this, request.connection, connection_builder.end(), null);
			this.requests.unset(request.request_id);
		}

		private bool connection_always_ask(NM.Connection connection)
		{
			var s_con = (NM.SettingConnection) connection.get_setting(typeof(NM.SettingConnection));
			var setting = connection.get_setting_by_name(s_con.get_connection_type());
			if (setting == null) {
				return false;
			}

			var candidates = new Gee.ArrayList<NM.Setting>();
			candidates.add(setting);
			if (setting is NM.SettingWireless) {
				var wifi_sec = connection.get_setting(typeof(NM.SettingWirelessSecurity));
				if (wifi_sec != null) {
					candidates.add(wifi_sec);
				}
				var ieee = connection.get_setting(typeof(NM.Setting8021x));
				if (ieee != null) {
					candidates.add(ieee);
				}
			} else if (setting is NM.SettingWired) {
				var pppoe = connection.get_setting(typeof(NM.SettingPppoe));
				if (pppoe != null) {
					candidates.add(pppoe);
				}
				var ieee = connection.get_setting(typeof(NM.Setting8021x));
				if (ieee != null) {
					candidates.add(ieee);
				}
			}

			foreach (var candidate in candidates) {
				var always_ask = false;
				candidate.enumerate_values((s, key, value, flags) => {
					if ((flags & ((GLib.ParamFlags) NM.Setting.SECRET)) == 0) {
						return;
					}
					try {
						NM.SettingSecretFlags secret_flags;
						if (!nm_get_secret_flags(s, key, out secret_flags)) {
							return;
						}
						if ((secret_flags & NM.SettingSecretFlags.NOT_SAVED) != 0) {
							always_ask = true;
						}
					} catch (GLib.Error e) {
					}
				});
				if (always_ask) {
					return true;
				}
			}
			return false;
		}
	}
}
