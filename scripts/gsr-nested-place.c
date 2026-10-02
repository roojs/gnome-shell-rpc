/* Pin mutter's nested stage window.
 *
 * Weston desktop-shell places an X window at random unless the client
 * claims a position. Mutter's nested stage sets only min/max size, so
 * each launch lands somewhere else inside Weston.
 *
 * USPosition plus a move before map makes Weston keep map_request.
 */
#include <dlfcn.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

static int
is_gsr_server(void)
{
	char comm[64];
	int fd;
	ssize_t n;

	fd = open("/proc/self/comm", O_RDONLY);
	if (fd < 0)
		return 0;
	n = read(fd, comm, sizeof comm - 1);
	close(fd);
	if (n <= 0)
		return 0;
	comm[n] = '\0';
	return strncmp(comm, "gsr-server", 10) == 0;
}

static int
env_int(const char *name, int fallback)
{
	const char *v = getenv(name);
	if (v == NULL || v[0] == '\0')
		return fallback;
	return atoi(v);
}

void
XSetWMNormalHints(Display *display, Window window, XSizeHints *hints)
{
	static void (*real_set)(Display *, Window, XSizeHints *) = NULL;
	XSizeHints copy;
	int x;
	int y;

	if (real_set == NULL)
		real_set = dlsym(RTLD_NEXT, "XSetWMNormalHints");

	if (!is_gsr_server()
			|| hints == NULL
			|| (hints->flags & (PMinSize | PMaxSize)) != (PMinSize | PMaxSize)
			|| hints->min_width != hints->max_width
			|| hints->min_height != hints->max_height
			|| hints->min_width < 100)
	{
		real_set(display, window, hints);
		return;
	}

	copy = *hints;
	x = env_int("GSR_NESTED_X", 0);
	y = env_int("GSR_NESTED_Y", 32);
	copy.flags |= USPosition;
	copy.x = x;
	copy.y = y;
	real_set(display, window, &copy);
	XMoveWindow(display, window, x, y);
}
