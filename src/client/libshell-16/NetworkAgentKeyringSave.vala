/**
 * Keyring write-back for {@link NetworkAgent.save_secrets}.
 */
namespace Shell
{
	internal class NetworkAgentKeyringSave
	{
		public NetworkAgent agent;
		public NM.Connection connection;
		public NM.SecretAgentOldSaveSecretsFunc? callback;
		public int n_secrets = 0;

		public NetworkAgentKeyringSave(
			NetworkAgent agent,
			NM.Connection connection,
			owned NM.SecretAgentOldSaveSecretsFunc? callback
		) {
			this.agent = agent;
			this.connection = connection;
			this.callback = (owned) callback;
		}

		public void write_all()
		{
			this.connection.for_each_setting_value((setting, key, value, flags) => {
				if ((flags & ((GLib.ParamFlags) NM.Setting.SECRET)) == 0) {
					return;
				}
				if (setting is NM.SettingVpn && key == NM.SettingVpn.SECRETS) {
					((NM.SettingVpn) setting).foreach_secret((vpn_key, secret) => {
						if (secret == null || secret.length == 0) {
							return;
						}
						var label = "VPN %s secret for %s/%s/%s".printf(vpn_key,
							this.connection.get_id(),
							((NM.SettingVpn) setting).get_service_type(),
							NM.SettingVpn.SETTING_NAME);
						this.store_one(setting, vpn_key, secret, label);
					});
					return;
				}
				if (!value.holds(typeof(string))) {
					return;
				}
				var secret = value.get_string();
				if (secret != null && secret.length > 0) {
					this.store_one(setting, key, secret, null);
				}
			});
			if (this.n_secrets == 0 && this.callback != null) {
				this.callback(this.agent, this.connection, null);
			}
		}

		private void store_one(NM.Setting setting, string key, string secret, string? display_name)
		{
			/* Only save agent-owned secrets (not system-owned or always-ask). */
			NM.SettingSecretFlags secret_flags = NM.SettingSecretFlags.NONE;
			try {
				NetworkAgent.nm_get_secret_flags(setting, key, out secret_flags);
			} catch (GLib.Error e) {
			}
			if (secret_flags != NM.SettingSecretFlags.AGENT_OWNED) {
				return;
			}

			var setting_name = setting.get_name();
			var attrs = new GLib.HashTable<string, string>(GLib.str_hash, GLib.str_equal);
			attrs.set(NetworkAgent.KEYRING_UUID_TAG, this.connection.get_uuid());
			attrs.set(NetworkAgent.KEYRING_SN_TAG, setting_name);
			attrs.set(NetworkAgent.KEYRING_SK_TAG, key);
			var label = display_name;
			if (label == null) {
				label = "Network secret for %s/%s/%s".printf(
					this.connection.get_id(), setting_name, key);
			}
			this.n_secrets++;
			Secret.password_storev.begin(this.agent.schema, attrs,
				Secret.COLLECTION_DEFAULT, label, secret, null, (obj, res) => {
					try {
						Secret.password_storev.end(res);
					} catch (GLib.Error e) {
					}
					this.n_secrets--;
					if (this.n_secrets == 0 && this.callback != null) {
						this.callback(this.agent, this.connection, null);
					}
				});
		}
	}
}
