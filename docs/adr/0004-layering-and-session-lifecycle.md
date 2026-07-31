# Layered architecture with Riverpod; per-Worksheet Session as an autoDispose family

**Status:** accepted

VoltQuery uses a layered `domain / data / ui` architecture (per the Flutter
architecture skill: Repository pattern, MVVM, hybrid folders — data/domain by
type, UI by feature), with **driver ports in `domain/drivers`** and **adapters in
`data/drivers`** (ports & adapters). We adapt the skill's `ChangeNotifier` +
`get_it` to **Riverpod** (the standing state choice): ViewModels are
`Notifier`/`AsyncNotifier`s, Views are `ConsumerWidget`s, and DI is the provider
graph. Full layout: `docs/design/architecture.md`.

The non-obvious bet worth recording: **a Worksheet's live Session is modeled as a
Riverpod `autoDispose.family<Session, WorksheetId>`**, not an imperative
`SessionManager` holding a `Map<WorksheetId, Session>`. Because the domain model
gives each Worksheet its own tx-isolated Session, tying the Session to its tab's
provider means closing a tab disposes the provider and `onDispose` closes the
Session automatically — no hand-managed lifecycle to leak. The trade-off:
lifecycle is implicit in provider disposal rather than explicit calls, which a
reader expecting a service-with-a-map will find surprising — hence this record.

**Consequence to honor:** don't reintroduce a global mutable SessionManager
"for visibility" — it re-opens the leak-and-shared-state problems both this and
ADR-0002 exist to prevent. A future "share a Session across tabs" feature is an
explicit opt-in override of the family, not the default.
