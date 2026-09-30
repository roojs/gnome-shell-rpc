/**
 * Owned {@code Shell.AppUsage} — stock {@code shell-app-usage} (0.7.7 T-041).
 * Scores rise while an app holds focus (same FOCUS_TIME idea as stock).
 */
namespace Shell
{
	public class AppUsage : GLib.Object
	{
		private static AppUsage? instance;
		private GLib.HashTable<string, double?> app_scores {
			get; set;
			default = new GLib.HashTable<string, double?>(GLib.str_hash, GLib.str_equal);
		}
		private App? watched_app;
		private int64 watch_start_us;

		public static AppUsage get_default()
		{
			if (instance == null) {
				instance = new AppUsage();
			}
			return instance;
		}

		construct {
			var tracker = WindowTracker.get_default();
			tracker.notify["focus-app"].connect(() => {
				var now = GLib.get_real_time();
				if (this.watched_app != null) {
					this.increment_usage(this.watched_app, now);
				}
				this.watched_app = tracker.focus_app;
				this.watch_start_us = now;
			});
			this.watched_app = tracker.focus_app;
			this.watch_start_us = GLib.get_real_time();
		}

		private void increment_usage(App app, int64 now_us)
		{
			var id = app.id;
			if (id.length == 0) {
				return;
			}
			/* Stock FOCUS_TIME_MIN_SECONDS = 5 — count whole intervals. */
			var elapsed_s = (now_us - this.watch_start_us) / GLib.TimeSpan.SECOND;
			var usage_count = elapsed_s / 5;
			if (usage_count < 1) {
				return;
			}
			var score = this.app_scores.lookup(id) ?? 0;
			score += usage_count;
			if (score > 100) {
				this.normalize_usage();
				score = this.app_scores.lookup(id) ?? 0;
				score += usage_count;
			}
			this.app_scores.insert(id, score);
		}

		private void normalize_usage()
		{
			this.app_scores.foreach((id, score) => {
				if (score != null) {
					this.app_scores.insert(id, score / 2);
				}
			});
		}

		/**
		 * Stock: -1 if {@code id_a} ranks higher, 1 if {@code id_b} higher, 0 tie.
		 */
		public int compare(string id_a, string id_b)
		{
			var score_a = this.app_scores.lookup(id_a);
			var score_b = this.app_scores.lookup(id_b);
			if (score_a == null && score_b == null) {
				return 0;
			}
			if (score_a == null) {
				return 1;
			}
			if (score_b == null) {
				return -1;
			}
			if (score_b > score_a) {
				return 1;
			}
			if (score_a > score_b) {
				return -1;
			}
			return 0;
		}

		public GLib.SList<weak App> get_most_used()
		{
			var appsys = AppSystem.get_default();
			var ids = new string[0];
			this.app_scores.foreach((id, score) => {
				ids += id;
			});
			for (int i = 0; i < ids.length; i++) {
				for (int j = i + 1; j < ids.length; j++) {
					if (this.compare(ids[i], ids[j]) > 0) {
						var tmp = ids[i];
						ids[i] = ids[j];
						ids[j] = tmp;
					}
				}
			}
			var list = new GLib.SList<weak App>();
			foreach (var id in ids) {
				var app = appsys.lookup_app(id);
				if (app != null) {
					list.append(app);
				}
			}
			return list;
		}
	}
}
