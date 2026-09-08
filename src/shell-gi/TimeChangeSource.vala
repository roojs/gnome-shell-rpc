/**
 * Stock {@code shell_time_change_source_new} — GSource that fires when the
 * realtime clock jumps relative to monotonic (NTP, etc.).
 */
namespace Shell
{
	[CCode (cname = "itimerspec", cheader_filename = "time.h", has_type_id = false)]
	struct ITimerspec
	{
		Posix.timespec it_interval;
		Posix.timespec it_value;
	}

	[CCode (cname = "timerfd_create", cheader_filename = "sys/timerfd.h")]
	static extern int timerfd_create(int clock_id, int flags);

	[CCode (cname = "timerfd_settime", cheader_filename = "sys/timerfd.h")]
	static extern int timerfd_settime(int fd, int flags, ITimerspec *new_value, ITimerspec *old_value);

	const int CLOCK_REALTIME = 0;
	const int TFD_NONBLOCK = 0x800;
	const int TFD_CLOEXEC = 0x80000;
	const int TFD_TIMER_ABSTIME = 1 << 0;
	const int TFD_TIMER_CANCEL_ON_SET = 1 << 1;

	class TimeChangeSourceImpl : GLib.Source
	{
		public int fd = -1;
		public void* tag;

		public TimeChangeSourceImpl() throws GLib.Error
		{
			this.fd = timerfd_create(CLOCK_REALTIME, TFD_NONBLOCK | TFD_CLOEXEC);
			if (this.fd < 0 || arm_timerfd(this.fd) < 0) {
				int errsv = Posix.errno;
				if (this.fd >= 0) {
					Posix.close(this.fd);
					this.fd = -1;
				}
				throw new GLib.FileError.FAILED(
					"Error creating timerfd: %s", Posix.strerror(errsv));
			}
			this.tag = this.add_unix_fd(this.fd, GLib.IOCondition.IN);
		}

		~TimeChangeSourceImpl()
		{
			this.cleanup_fd();
		}

		static int arm_timerfd(int fd)
		{
			ITimerspec its = {};
			its.it_value.tv_sec = (time_t) ((sizeof(time_t) >= 8) ? uint64.MAX : uint32.MAX);
			int flags = TFD_TIMER_ABSTIME | TFD_TIMER_CANCEL_ON_SET;
			if (timerfd_settime(fd, flags, &its, null) == 0) {
				return 0;
			}
			if (Posix.errno != Posix.EINVAL) {
				return -1;
			}
			its.it_value.tv_sec = (time_t) uint32.MAX;
			return timerfd_settime(fd, flags, &its, null);
		}

		public void cleanup_fd()
		{
			if (this.tag != null) {
				this.remove_unix_fd(this.tag);
				this.tag = null;
			}
			if (this.fd >= 0) {
				Posix.close(this.fd);
				this.fd = -1;
			}
		}

		public override bool prepare(out int timeout)
		{
			timeout = -1;
			return false;
		}

		public override bool check()
		{
			return false;
		}

		public override bool dispatch(GLib.SourceFunc? callback)
		{
			if (callback == null) {
				GLib.warning(
					"TimeChangeSource dispatched without callback. "
					+ "You must call Source.set_callback().");
				return GLib.Source.REMOVE;
			}
			if (callback()) {
				int retval = arm_timerfd(this.fd);
				assert(retval == 0 || (retval < 0 && Posix.errno == Posix.ECANCELED));
				return GLib.Source.CONTINUE;
			}
			this.cleanup_fd();
			return GLib.Source.REMOVE;
		}
	}

	/**
	 * Stock {@code shell_time_change_source_new}.
	 */
	public GLib.Source time_change_source_new() throws GLib.Error
	{
		return new TimeChangeSourceImpl();
	}
}
