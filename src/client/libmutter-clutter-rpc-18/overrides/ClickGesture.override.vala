		/**
		 * GIR exposes {@link ActorMeta.get_enabled} / {@code set_enabled},
		 * not a property. GJS still assigns {@code gesture.enabled}
		 * (desktop-cube disables the panel window-drag gesture this way).
		 * The write is deferred to an idle. Doing it in the setter runs
		 * nested inside {@code Clutter-ClickGesture.new} and that aborts
		 * the lease call. The class already has the lease construct
		 * block, so this cannot sync from a second one.
		 */
		private bool priv_enabled = true;
		private uint enabled_idle = 0;

		private void queue_enabled_sync()
		{
			if (this.enabled_idle != 0) {
				return;
			}
			this.enabled_idle = Idle.add(() => {
				this.enabled_idle = 0;
				if (this.rpc_lid != 0) {
					this.set_enabled(this.priv_enabled);
				}
				return Source.REMOVE;
			});
		}

		public bool enabled {
			get {
				return this.priv_enabled;
			}
			set construct {
				this.priv_enabled = value;
				this.queue_enabled_sync();
			}
		}
