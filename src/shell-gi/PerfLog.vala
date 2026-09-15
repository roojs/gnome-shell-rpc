/**
 * Owned {@code Shell.PerfLog} — stock {@code shell-perf-log} for looking-glass
 * / {@code scripting.js} dumps.
 */
namespace Shell
{
	private class PerfEvent
	{
		public uint16 id;
		public string name;
		public string description;
		public string signature;
	}

	private class PerfStatistic
	{
		public PerfEvent event;
		public int current_i;
		public int last_i;
		public int64 current_x;
		public int64 last_x;
		public bool initialized;
		public bool recorded;
	}

	private class PerfStatsClosure
	{
		public PerfStatisticsCallback callback;
	}

	private class PerfBlock
	{
		public uint32 bytes;
		public uint8[] buffer;

		public PerfBlock()
		{
			this.buffer = new uint8[8192];
			this.bytes = 0;
		}
	}

	public delegate void PerfStatisticsCallback(PerfLog perf_log);
	public delegate void PerfReplayFunction(int64 time, string name, string signature, GLib.Value arg);

	public class PerfLog : GLib.Object
	{
		private static PerfLog? singleton;

		private Gee.ArrayList<PerfEvent> events {
			get; set; default = new Gee.ArrayList<PerfEvent>();
		}
		private Gee.HashMap<string, PerfEvent> events_by_name {
			get; set; default = new Gee.HashMap<string, PerfEvent>();
		}
		private Gee.ArrayList<PerfStatistic> statistics {
			get; set; default = new Gee.ArrayList<PerfStatistic>();
		}
		private Gee.HashMap<string, PerfStatistic> statistics_by_name {
			get; set; default = new Gee.HashMap<string, PerfStatistic>();
		}
		private Gee.ArrayList<PerfStatsClosure> statistics_callbacks {
			get; set; default = new Gee.ArrayList<PerfStatsClosure>();
		}
		private GLib.Queue<PerfBlock> blocks = new GLib.Queue<PerfBlock>();

		private int64 start_time;
		private int64 last_time;
		private uint statistics_timeout_id;
		private bool enabled;

		construct {
			this.define_event("perf.setTime", "", "x");
			assert(this.events.size == 1);
			this.define_event("perf.statisticsCollected",
				"Finished collecting statistics", "x");
			assert(this.events.size == 2);
			this.start_time = this.last_time = GLib.get_monotonic_time();
		}

		public static unowned PerfLog get_default()
		{
			if (singleton == null) {
				singleton = new PerfLog();
			}
			return singleton;
		}

		public void set_enabled(bool enabled)
		{
			if (enabled == this.enabled) {
				return;
			}
			this.enabled = enabled;
			if (!enabled) {
				if (this.statistics_timeout_id != 0) {
					GLib.Source.remove(this.statistics_timeout_id);
					this.statistics_timeout_id = 0;
				}
				return;
			}
			this.statistics_timeout_id = GLib.Timeout.add(5000, () => {
				this.collect_statistics();
				return GLib.Source.CONTINUE;
			});
		}

		public void define_event(string name, string description, string signature)
		{
			if (signature != "" && signature != "s"
					&& signature != "i" && signature != "x") {
				GLib.warning("Only supported event signatures are '', 's', 'i', and 'x'");
				return;
			}
			if (this.events.size == 65536) {
				GLib.warning("Maximum number of events defined");
				return;
			}
			if (name.index_of_char('"') >= 0) {
				GLib.warning("Event names can't include '\"'");
				return;
			}
			if (this.events_by_name.has_key(name)) {
				GLib.warning("Duplicate event event for '%s'", name);
				return;
			}
			var event = new PerfEvent() {
				id = (uint16) this.events.size,
				name = name,
				description = description,
				signature = signature
			};
			this.events.add(event);
			this.events_by_name[event.name] = event;
		}

		private PerfEvent? lookup_event(string name, string signature)
		{
			if (!this.events_by_name.has_key(name)) {
				GLib.warning("Discarding unknown event '%s'", name);
				return null;
			}
			var event = this.events_by_name[name];
			if (event.signature != signature) {
				GLib.warning("Event '%s'; defined with signature '%s', used with '%s'",
					name, event.signature, signature);
				return null;
			}
			return event;
		}

		private void record_event(int64 event_time, PerfEvent event, uint8[]? payload)
		{
			if (!this.enabled) {
				return;
			}
			var bytes_len = 0;
			if (payload != null) {
				bytes_len = payload.length;
			}
			var total_bytes = (size_t) (sizeof(int32) + sizeof(int16) + bytes_len);
			if (bytes_len > 8192 || total_bytes > 8192) {
				GLib.warning("Discarding oversize event '%s'", event.name);
				return;
			}

			var time_delta = (uint32) 0;
			if (event_time > this.last_time + 0xffffffff) {
				this.last_time = event_time;
				var set_time = new uint8[sizeof(int64)];
				GLib.Memory.copy(set_time, &event_time, sizeof(int64));
				this.record_event(event_time,
					this.lookup_event("perf.setTime", "x"), set_time);
			} else if (event_time >= this.last_time) {
				time_delta = (uint32) (event_time - this.last_time);
			}
			this.last_time = event_time;

			var block = this.blocks.peek_tail();
			if (block == null || total_bytes + block.bytes > 8192) {
				block = new PerfBlock();
				this.blocks.push_tail(block);
			}

			var pos = block.bytes;
			var delta_bytes = new uint8[sizeof(uint32)];
			GLib.Memory.copy(delta_bytes, &time_delta, sizeof(uint32));
			GLib.Memory.copy(&block.buffer[pos], delta_bytes, sizeof(uint32));
			pos += (uint32) sizeof(uint32);
			var id_bytes = new uint8[sizeof(uint16)];
			var event_id = event.id;
			GLib.Memory.copy(id_bytes, &event_id, sizeof(uint16));
			GLib.Memory.copy(&block.buffer[pos], id_bytes, sizeof(uint16));
			pos += (uint32) sizeof(uint16);
			if (payload != null && payload.length > 0) {
				GLib.Memory.copy(&block.buffer[pos], payload, payload.length);
				pos += (uint32) payload.length;
			}
			block.bytes = pos;
		}

		public void event(string name)
		{
			var ev = this.lookup_event(name, "");
			if (ev == null) {
				return;
			}
			this.record_event(GLib.get_monotonic_time(), ev, null);
		}

		public void event_i(string name, int32 arg)
		{
			var ev = this.lookup_event(name, "i");
			if (ev == null) {
				return;
			}
			var payload = new uint8[sizeof(int32)];
			GLib.Memory.copy(payload, &arg, sizeof(int32));
			this.record_event(GLib.get_monotonic_time(), ev, payload);
		}

		public void event_x(string name, int64 arg)
		{
			var ev = this.lookup_event(name, "x");
			if (ev == null) {
				return;
			}
			var payload = new uint8[sizeof(int64)];
			GLib.Memory.copy(payload, &arg, sizeof(int64));
			this.record_event(GLib.get_monotonic_time(), ev, payload);
		}

		public void event_s(string name, string arg)
		{
			var ev = this.lookup_event(name, "s");
			if (ev == null) {
				return;
			}
			var payload = new uint8[arg.length + 1];
			GLib.Memory.copy(payload, arg.data, arg.length);
			payload[arg.length] = 0;
			this.record_event(GLib.get_monotonic_time(), ev, payload);
		}

		public void define_statistic(string name, string description, string signature)
		{
			if (signature != "i" && signature != "x") {
				GLib.warning("Only supported statistic signatures are 'i' and 'x'");
				return;
			}
			var before = this.events.size;
			this.define_event(name, description, signature);
			if (this.events.size == before) {
				return;
			}
			var statistic = new PerfStatistic() {
				event = this.events[this.events.size - 1]
			};
			this.statistics.add(statistic);
			this.statistics_by_name[statistic.event.name] = statistic;
		}

		private PerfStatistic? lookup_statistic(string name, string signature)
		{
			if (!this.statistics_by_name.has_key(name)) {
				GLib.warning("Unknown statistic '%s'", name);
				return null;
			}
			var statistic = this.statistics_by_name[name];
			if (statistic.event.signature != signature) {
				GLib.warning("Statistic '%s'; defined with signature '%s', used with '%s'",
					name, statistic.event.signature, signature);
				return null;
			}
			return statistic;
		}

		public void update_statistic_i(string name, int value)
		{
			var statistic = this.lookup_statistic(name, "i");
			if (statistic == null) {
				return;
			}
			statistic.current_i = value;
			statistic.initialized = true;
		}

		public void update_statistic_x(string name, int64 value)
		{
			var statistic = this.lookup_statistic(name, "x");
			if (statistic == null) {
				return;
			}
			statistic.current_x = value;
			statistic.initialized = true;
		}

		public void add_statistics_callback(PerfStatisticsCallback callback)
		{
			var closure = new PerfStatsClosure() {
				callback = callback
			};
			this.statistics_callbacks.add(closure);
		}

		public void collect_statistics()
		{
			if (!this.enabled) {
				return;
			}
			var event_time = GLib.get_monotonic_time();
			foreach (var closure in this.statistics_callbacks) {
				closure.callback(this);
			}
			var collection_time = GLib.get_monotonic_time() - event_time;
			foreach (var statistic in this.statistics) {
				if (!statistic.initialized) {
					continue;
				}
				switch (statistic.event.signature[0]) {
					case 'i':
						if (statistic.recorded && statistic.current_i == statistic.last_i) {
							continue;
						}
						var payload_i = new uint8[sizeof(int32)];
						var v_i = statistic.current_i;
						GLib.Memory.copy(payload_i, &v_i, sizeof(int32));
						this.record_event(event_time, statistic.event, payload_i);
						statistic.last_i = statistic.current_i;
						statistic.recorded = true;
						break;

					case 'x':
						if (statistic.recorded && statistic.current_x == statistic.last_x) {
							continue;
						}
						var payload_x = new uint8[sizeof(int64)];
						var v_x = statistic.current_x;
						GLib.Memory.copy(payload_x, &v_x, sizeof(int64));
						this.record_event(event_time, statistic.event, payload_x);
						statistic.last_x = statistic.current_x;
						statistic.recorded = true;
						break;

					default:
						GLib.warning("Unsupported signature in event");
						break;
				}
			}
			var collected = new uint8[sizeof(int64)];
			GLib.Memory.copy(collected, &collection_time, sizeof(int64));
			this.record_event(event_time, this.events[1], collected);
		}

		public void replay(PerfReplayFunction replay_function)
		{
			var event_time = this.start_time;
			unowned GLib.List<PerfBlock> iter = this.blocks.head;
			while (iter != null) {
				var block = iter.data;
				var pos = (uint32) 0;
				while (pos < block.bytes) {
					var time_delta = (uint32) 0;
					GLib.Memory.copy(&time_delta, &block.buffer[pos], sizeof(uint32));
					pos += (uint32) sizeof(uint32);
					var id = (uint16) 0;
					GLib.Memory.copy(&id, &block.buffer[pos], sizeof(uint16));
					pos += (uint32) sizeof(uint16);
					if (id == 0) {
						GLib.Memory.copy(&event_time, &block.buffer[pos], sizeof(int64));
						pos += (uint32) sizeof(int64);
						continue;
					}
					event_time += time_delta;
					var event = this.events[(int) id];
					var arg = GLib.Value(typeof(string));
					switch (event.signature) {
						case "":
							arg = GLib.Value(typeof(string));
							arg.set_string("");
							break;

						case "i":
							var l_i = (int32) 0;
							GLib.Memory.copy(&l_i, &block.buffer[pos], sizeof(int32));
							pos += (uint32) sizeof(int32);
							arg = GLib.Value(typeof(int));
							arg.set_int(l_i);
							break;

						case "x":
							var l_x = (int64) 0;
							GLib.Memory.copy(&l_x, &block.buffer[pos], sizeof(int64));
							pos += (uint32) sizeof(int64);
							arg = GLib.Value(typeof(int64));
							arg.set_int64(l_x);
							break;

						case "s":
							unowned string s = (string) &block.buffer[pos];
							pos += (uint32) (s.length + 1);
							arg = GLib.Value(typeof(string));
							arg.set_string(s);
							break;
					}
					replay_function(event_time, event.name, event.signature, arg);
				}
				iter = iter.next;
			}
		}

		public bool dump_events(GLib.OutputStream out) throws GLib.Error
		{
			size_t written;
			out.write_all("[ ".data, out written);
			for (var i = 0; i < this.events.size; i++) {
				var event = this.events[i];
				var escaped_description = event.description;
				if (escaped_description.index_of_char('"') >= 0) {
					escaped_description = escaped_description.replace("\"", "\\\"");
				}
				if (i != 0) {
					out.write_all(",\n  ".data, out written);
				}
				var chunk = "{ \"name\": \"%s\",\n    \"description\": \"%s\"".printf(
					event.name, escaped_description);
				out.write_all(chunk.data, out written);
				if (this.statistics_by_name.has_key(event.name)) {
					out.write_all(",\n    \"statistic\": true".data, out written);
				}
				out.write_all(" }".data, out written);
			}
			return out.write_all(" ]".data, out written);
		}

		public bool dump_log(GLib.OutputStream out) throws GLib.Error
		{
			size_t written;
			out.write_all("[ ".data, out written);
			var first = true;
			GLib.Error? replay_error = null;
			this.replay((time, name, signature, arg) => {
				if (replay_error != null) {
					return;
				}
				try {
					if (!first) {
						out.write_all(",\n  ".data, out written);
					}
					first = false;
					var event_str = "";
					switch (signature) {
						case "":
							event_str = "[%lld, \"%s\"]".printf(time, name);
							break;

						case "i":
							event_str = "[%lld, \"%s\", %i]".printf(time, name, arg.get_int());
							break;

						case "x":
							event_str = "[%lld, \"%s\", %lld]".printf(time, name, arg.get_int64());
							break;

						case "s":
							var escaped = arg.get_string();
							if (escaped.index_of_char('"') >= 0) {
								escaped = escaped.replace("\"", "\\\"");
							}
							event_str = "[%lld, \"%s\", \"%s\"]".printf(time, name, escaped);
							break;

						default:
							assert_not_reached();
					}
					out.write_all(event_str.data, out written);
				} catch (GLib.Error e) {
					replay_error = e;
				}
			});
			if (replay_error != null) {
				throw replay_error;
			}
			return out.write_all(" ]".data, out written);
		}
	}
}
