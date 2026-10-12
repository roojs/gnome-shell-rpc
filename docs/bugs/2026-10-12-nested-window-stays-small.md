# Nested window stays small without debug

**Status:** ⏳ open. User 2026-10-12. In the Weston test session the nested Wayland window now opens in the right place. Without `--debug` it is still small. It should fill the Weston window, or a large part of it. A `--debug` session keeps the smaller size so the log terminal has room.

## Reproduction

By hand, no debug:

```bash
./scripts/weston-gsr-session.sh
```

Press the panel button. The nested window should cover the Weston window, or most of it.

With debug, the nested window stays at its default size:

```bash
./scripts/weston-gsr-session.sh --debug
```

## LLM efforts

### 2026-10-12 09:42 report created

Recorded from the user. No log read, no prove, no product change.
