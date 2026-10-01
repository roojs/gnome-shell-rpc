	/**
	 * Set when this device was rebuilt from a signal argument.
	 * A leased device leaves this false and reads the server.
	 */
	bool device_type_known;
	InputDeviceType device_type_priv;

	/**
	 * Denied so the generator does not emit it. The rebuilt X11
	 * device stores the type here. Any other device asks the server.
	 */
	public InputDeviceType device_type {
		get {
			if (this.device_type_known) {
				return this.device_type_priv;
			}
			var response = Gsr.call_value(
				"Clutter-InputDevice.get_device_type", this);
			return (InputDeviceType) response.retval.get_int();
		}
		set {
			this.device_type_priv = value;
			this.device_type_known = true;
		}
	}
