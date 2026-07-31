# Uniform driver-agnostic object hierarchy with optional levels

**Status:** accepted

VoltQuery models one canonical browsable hierarchy — `Server → Database → Schema → Object` — across all three engines, with levels declared present/absent by driver **Capabilities** (`hasServer`, `hasSchemas`) rather than by separate per-engine models. We chose this over engine-specific hierarchies (faithful but leaks `switch(engine)` into every consumer — tree, breadcrumbs, navigation) and over a fully generic recursive `Namespace` (flexible but loses the explicit Database/Schema vocabulary). The trade-off: MySQL collapses Schema into Database (they're synonyms) and SQLite collapses both Server and Schema (a file *is* the Database), which a future reader will find surprising — hence this record. The payoff is a single tree renderer, one mental model, and per-engine difference expressed as data (capability flags), not control flow.

**Consequence to honor:** consumers must render/traverse against the canonical shape and consult Capabilities to skip absent levels — never branch on Engine directly.
