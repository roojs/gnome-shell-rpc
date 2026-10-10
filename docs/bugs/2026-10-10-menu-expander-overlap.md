# Menu expander sits on the opened list

**Status:** Open. No `src/` edit. User, 2026-10-10: the expander on the dropdown menus is not drawn in the right place. The logout expander and the volume expander sit on top of the expanded list.

The volume one is the arrow on the volume row in quick settings (`QuickSlider._menuButton` in `vendor/gnome-shell/js/ui/quickSettings.js`). It opens the output list. The logout one is the power button (`ShutdownItem` in `vendor/gnome-shell/js/ui/status/system.js`). It opens the list that contains Log Out.

The volume slider itself is [Volume slider](done/2026-10-08-volume-slider-drawing.md), closed the same day. This file is only the expander placement.

## LLM efforts

2026-10-10. Filed from the user report. No log read. No reproduction. No `src/` edit.
