/**
 * Stock {@code ShellActionMode} bitfield (shell-action-modes.h).
 */
namespace Shell
{
	[Flags]
	public enum ActionMode
	{
		NONE = 0,
		NORMAL = 1,
		OVERVIEW = 2,
		LOCK_SCREEN = 4,
		UNLOCK_SCREEN = 8,
		LOGIN_SCREEN = 16,
		SYSTEM_MODAL = 32,
		LOOKING_GLASS = 64,
		POPUP = 128,
		ALL = -1
	}
}
