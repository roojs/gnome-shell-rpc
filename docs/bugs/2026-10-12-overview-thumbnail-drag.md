# Archived — overview thumbnail drag and click

Archived 2026-10-14. The log was too long to use. This file is not a finished fix.

The full text is [`archive/2026-10-12-overview-thumbnail-drag.md`](archive/2026-10-12-overview-thumbnail-drag.md).

Continue in one of these. Do not add to this file.

- [`2026-10-14-drag-scale-gone.md`](2026-10-14-drag-scale-gone.md) — drag starts, then `dnd.js:522` throws because `scale-x` has already stopped, and the grab stays.
- [`2026-10-14-drag-inside-preview.md`](2026-10-14-drag-inside-preview.md) — a move that stays on the preview never starts a drag.

Click-to-activate and the leave cancel (`event is null` at `dnd.js:151`) are fixed. They stay in the archive. Do not reopen them.
