/// The database engine kind. Every [Connection] has one. See `CONTEXT.md`.
enum Engine {
  postgres,
  mysql,
  sqlite;

  /// How the engine is written in the UI.
  String get label => switch (this) {
    Engine.postgres => 'PostgreSQL',
    Engine.mysql => 'MySQL',
    Engine.sqlite => 'SQLite',
  };
}
