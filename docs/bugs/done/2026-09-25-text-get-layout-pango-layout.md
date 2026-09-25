# `Clutter.Text.get_layout` return type is `Pango.Layout`

**Status:** ✔️ archived 2026-09-25. Helper + client rebuild landed. The later
negative preferred-height failure is also archived —
[`2026-09-25-box-layout-negative-min-height.md`](2026-09-25-box-layout-negative-min-height.md).

**Plan:** [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

## Seen

```text
id=11888 method=Clutter-Text.get_layout
replied id=11888 error=
Clutter-Text.get_layout id=11888:
uncaught error: (oll-mrpc-rpc-error-code-quark, -32602)
JS ERROR: TypeError: layout is null
_updateExpandButton@resource:///org/gnome/shell/ui/messageList.js:542:27
```

Next call, id 11889, replies. Mutter only logs `recv` for 11888. No server error line.

## Issue

Generated `Clutter.Text.get_layout()` returns `Pango.Layout?`:

```vala
public Pango.Layout? get_layout()
```

`Pango.Layout` is not a wire type. The reply is `-32602` (invalid params). The getter returns null. `messageList.js` uses that layout and throws.

## Handle

**ℹ️** The consumer is not supposed to modify the layout. `Clutter.Text` owns it and hands it out only to read. The caller must not change it or free it.

**🔷** Server override of `Clutter.Text.get_layout` plus a helper. The helper reads the server layout and returns the fields below as arguments. The client override rebuilds a `Pango.Layout` from those arguments and returns it. Methods such as `is_ellipsized` run on that copy. Writes on the client do not go back.

| Field | On the wire |
| --- | --- |
| text | string |
| font | `pango_font_description_to_string` |
| width, height | int |
| wrap, ellipsize, alignment | enum |
| indent, spacing | int |
| attributes | `Pango.AttrList` — the part that is not a plain field |

**ℹ️** The client font metrics can differ from mutter’s. If `is_ellipsized` then disagrees with the server, this snapshot is wrong and it has to be a lease instead.

Seen call sites, not the API:

| Call | Methods |
| --- | --- |
| `messageList.js` `_updateExpandButton` | `is_ellipsized()` |
| `appDisplay.js` `_updateMultiline` | `is_wrapped()`, `is_ellipsized()` |

## Landed

- `src/rpc/helper/Text.vala` — `Helper-Text.get_layout`
- `src/gi-stub/overrides-clutter/Text.override.vala`
- `Text.get_layout` in `src/gi-stub-gen/Clutter.deny`
