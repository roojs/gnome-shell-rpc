# Dash launches and workspace switches do not take

**Status:** ⏳ open. Recorded 2026-10-08 from the nested Weston session. No log read, no prove. The user stopped here and left.

That session stayed up. It was not crashing and it was not hanging.

2026-10-09: the user says Weston crashes often after the thumbnail changes. The tiny picture in the top workspace tabs, the missing main window previews, and those crashes are [`2026-10-06-overview-no-thumbnails.md`](2026-10-06-overview-no-thumbnails.md).

Windows missing from the overview are [`2026-10-06-overview-no-thumbnails.md`](2026-10-06-overview-no-thumbnails.md). That file stays that bug. The shell going dead after a second picker launch is [`2026-10-07-picker-click-no-clicked.md`](2026-10-07-picker-click-no-clicked.md), held because the user could not reproduce it.

## What happened

Nested Weston, started with Run. Apps were started from the dash at the bottom.

Some of those launches never started. The apps did not come up.

Two apps did run. Each showed the running dot on its dash icon. That part is right.

Clicking those running icons did not bring the app up, and did not switch to the desktop that app was on.

Choosing a workspace by its number (1, 2, 3, 4, 5) usually did nothing. The choice did not show as active in the toolbar at the top, and the view did not go to that workspace. Once or twice it did switch, and it was then possible to go back. The reaction to the selection was flaky.

## Reproduce this

By hand, on the nested Weston session:

🔷 Start the session and leave it up.

🔷 From the dash at the bottom, start a few apps. Expected: each one starts. Actual: some never start.

🔷 For an app that is running (dot on its dash icon), click that icon. Expected: that app comes to the front, on its desktop. Actual: nothing appears, and the desktop does not change.

🔷 Choose workspace 1, then 2, then 3, then 4, then 5. Expected: the top toolbar marks the one you chose, and the view goes there. Actual: usually neither happens. Sometimes the view does change, and you can change back.

## What is not this bug

ℹ️ Window pictures missing from the overview. Already tracked.

ℹ️ A second picker launch leaving the shell dead. Held. This session stayed up.
