# Each Worksheet owns its own Session (transaction isolation per tab)

**Status:** accepted

Every Worksheet (the unit shown as a UI Tab) opens its **own** Session — its own live connection to the server — rather than sharing one Session per Connection across tabs. We chose isolation because sharing would let a `BEGIN`, `USE db`, temp table, or session variable in one tab silently bleed into another, which is surprising and bug-prone. The cost is more concurrent connections held open per server; we accept it because it matches the user's mental model of independent worksheets and keeps transaction state legible. A reader tempted to "save connections" by pooling one Session across tabs should not — that reintroduces the cross-tab state bleed this decision exists to prevent.

**Consequence to honor:** cardinality is `Connection 1..* Session`, `Session 1..1 Worksheet`. A future "share a session to see an uncommitted transaction" power feature would be an explicit opt-in, not the default.
