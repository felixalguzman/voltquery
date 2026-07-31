# `panes` for resizable IDE layout (editor↔grid splitter + shell)

**Status:** accepted

VoltQuery uses the [`panes`](https://pub.dev/packages/panes) package for its
resizable multi-pane layout — the editor↔grid splitter (issue #15) and the shell
(sidebar + main + panels, `ui/core/shell`). `panes` bundles resizable
horizontal/vertical panes, a tab system, keyboard-accessible resizers, an IDE
layout template, and **pane/tab state serialization** (which pairs with the
worksheet draft-restore of ADR-0005). `UI_STACK.md` never chose a split/pane
package, so this fills a gap rather than revising a locked choice.

The trade-off worth recording: `panes` is **young and low-adoption** (~25 likes,
160 pub points at selection) for a *foundational layout* dependency — a real
bus-factor/maturity risk. We chose it anyway over the more battle-tested
`multi_split_view` + `docking` combo because its all-in-one feature set (panes +
tabs + state restore + IDE template) matches the DBeaver-alt shell in one
dependency; it is MIT-licensed, so forkable if it stalls.

**Consequence to honor:** keep `panes` usage behind our own shell/splitter
widgets in `ui/core/shell` and `ui/features/query_workspace`, so swapping to
`multi_split_view`/`docking` later is a localized change, not an app-wide one.
