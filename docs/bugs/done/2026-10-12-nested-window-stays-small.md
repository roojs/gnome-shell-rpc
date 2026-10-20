# Nested window stays small without debug

**Status:** ✔️ archived 2026-10-20 — taken off the board. Debug-session window size only. The user said it is not important.

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

### 2026-10-20 archived

User: archive it. Only for debugging. Reduce the number of bugs.
