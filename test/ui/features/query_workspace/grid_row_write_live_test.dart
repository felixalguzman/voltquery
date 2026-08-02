import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/driver_factory.dart';
import 'package:voltquery/domain/drivers/driver.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/connection_options.dart';
import 'package:voltquery/domain/models/ssl_mode.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/domain/sql/sql_statement_splitter.dart';
import 'package:voltquery/ui/features/query_workspace/grid_edit_buffer.dart';
import 'package:voltquery/ui/features/query_workspace/grid_editability.dart';
import 'package:voltquery/ui/features/schema_browser/schema_repository.dart';

/// The grid's staged changes, **actually executed against a real engine**.
///
/// Every other grid test stops at the generated string, which proves the
/// builder agrees with itself and nothing more. These take the path a user
/// takes — run a SELECT, resolve editability from the live catalog, stage rows,
/// generate SQL, execute it, re-query — so a statement an engine rejects fails
/// here rather than in front of someone's data.
///
/// SQLite runs everywhere (in-memory). Postgres and MySQL need a server, so
/// they read connection details from the environment and **skip** when it isn't
/// set — a missing server must not look like a passing test:
///
/// ```
/// VOLTQUERY_PG=postgres://user:pass@localhost:5432/dbname \
/// VOLTQUERY_MYSQL=mysql://root:pass@localhost:3306/dbname \
///   flutter test test/ui/features/query_workspace/grid_row_write_live_test.dart
/// ```
void main() {
  _engineSuite(
    label: 'sqlite',
    engine: Engine.sqlite,
    dialect: SqlDialect.sqlite,
    config: const _LiveConfig(
      connection: Connection(
        id: 't',
        name: 'mem',
        engine: Engine.sqlite,
        sqlitePath: ':memory:',
      ),
    ),
    // SQLite has no real BOOLEAN and stores 0/1.
    trueLiteral: 1,
    falseLiteral: 0,
    autoKey: 'INTEGER PRIMARY KEY',
    boolType: 'BOOLEAN NOT NULL DEFAULT 1',
  );

  _engineSuite(
    label: 'postgres',
    engine: Engine.postgres,
    dialect: SqlDialect.postgres,
    config: _fromEnv('VOLTQUERY_PG', Engine.postgres, 5432,
        sslMode: SslMode.disable),
    trueLiteral: true,
    falseLiteral: false,
    autoKey: 'SERIAL PRIMARY KEY',
    boolType: 'BOOLEAN NOT NULL DEFAULT TRUE',
  );

  _engineSuite(
    label: 'mysql',
    engine: Engine.mysql,
    dialect: SqlDialect.mysql,
    config: _fromEnv('VOLTQUERY_MYSQL', Engine.mysql, 3306,
        sslMode: SslMode.require),
    // mysql_client hands a TINYINT(1) back as **text**, not a number. The grid
    // already copes (`_truthy` accepts '1'/'0' and `_asOriginalShape` preserves
    // whichever spelling the engine used), which is exactly why those exist.
    trueLiteral: '1',
    falseLiteral: '0',
    autoKey: 'INT AUTO_INCREMENT PRIMARY KEY',
    boolType: 'BOOLEAN NOT NULL DEFAULT TRUE',
  );
}

/// Where a live server's details come from, or null when the env var is unset.
class _LiveConfig {
  const _LiveConfig({required this.connection, this.secret});
  final Connection connection;
  final String? secret;
}

/// Parses `scheme://user:pass@host:port/database` out of [varName].
///
/// [sslMode] differs by engine and both values are deliberate. A stock Postgres
/// container speaks no TLS at all, so the app's secure default has to be opted
/// out of explicitly — weakening the default instead would be the wrong fix.
/// MySQL 8 is the opposite: `caching_sha2_password` refuses to authenticate
/// over a plaintext socket, so the connection must be encrypted to work at all.
_LiveConfig? _fromEnv(
  String varName,
  Engine engine,
  int defaultPort, {
  required SslMode sslMode,
}) {
  final raw = Platform.environment[varName];
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.parse(raw);
  final userInfo = uri.userInfo.split(':');
  return _LiveConfig(
    connection: Connection(
      id: 'live-${engine.name}',
      name: 'live ${engine.name}',
      engine: engine,
      host: uri.host.isEmpty ? 'localhost' : uri.host,
      port: uri.port == 0 ? defaultPort : uri.port,
      username: userInfo.first,
      defaultDatabase: uri.pathSegments.isEmpty ? null : uri.pathSegments.first,
      options: ConnectionOptions(sslMode: sslMode),
    ),
    secret: userInfo.length > 1 ? userInfo[1] : null,
  );
}

/// One engine's worth of the suite. [config] null → the whole group skips.
void _engineSuite({
  required String label,
  required Engine engine,
  required SqlDialect dialect,
  required _LiveConfig? config,
  required Object trueLiteral,
  required Object falseLiteral,
  required String autoKey,
  required String boolType,
}) {
  group('[$label]', () {
    late Session session;
    late GridEditabilityResolver resolver;
    // Unique per engine so a server shared with something else stays tidy.
    const table = 'vq_grid_live';

    setUp(() async {
      final driver = driverFor(engine);
      session = await driver.connect(config!.connection, secret: config.secret);
      await session.execute('DROP TABLE IF EXISTS $table');
      await session.execute(
        'CREATE TABLE $table ('
        '  id $autoKey,'
        '  name VARCHAR(120),'
        '  email VARCHAR(120) UNIQUE,'
        '  total DECIMAL(10,2),'
        '  active $boolType'
        ')',
      );
      await session.execute(
        "INSERT INTO $table (name, email, total, active) VALUES "
        "('Ada', 'ada@x.io', 10.50, TRUE),"
        "('Grace', 'grace@x.io', 20.00, TRUE),"
        "('Katherine', 'kat@x.io', 30.25, FALSE)",
      );
      resolver = GridEditabilityResolver(
        engine: engine,
        repo: SchemaRepository(
          introspector: session.schema,
          capabilities: driver.capabilities,
        ),
      );
    });

    tearDown(() async {
      await session.execute('DROP TABLE IF EXISTS $table');
      await session.close();
    });

    Future<List<List<Object?>>> query(String sql) async {
      final result = await session.execute(sql) as RowsResult;
      final rows = await result.cursor.fetch(1000);
      await result.cursor.close();
      return [for (final r in rows) r.values];
    }

    /// The id of each surviving row, in order — the cheapest proof of what a
    /// DELETE or INSERT actually did.
    Future<List<Object?>> names() async =>
        (await query('SELECT name FROM $table ORDER BY id'))
            .map((r) => r.single)
            .toList();

    /// Runs a buffer's statements the way `applyGridEdits` does: in order,
    /// inside one transaction.
    Future<List<String>> apply(
      GridEditBuffer buf,
      GridEditability editability,
      Map<String, Object?>? Function(int) pkValuesFor,
    ) async {
      final statements = buf.toSql(
        editability: editability,
        dialect: dialect,
        pkValuesFor: pkValuesFor,
      );
      await session.begin();
      for (final sql in statements) {
        await session.execute(sql);
      }
      await session.commit();
      return statements;
    }

    /// Result row i ↔ the id the seed gave it. Read back rather than assumed:
    /// SERIAL and AUTO_INCREMENT don't have to start at 1.
    Future<Map<String, Object?>? Function(int)> identities() async {
      final ids = (await query('SELECT id FROM $table ORDER BY id'))
          .map((r) => r.single)
          .toList();
      return (i) => i < ids.length ? {'id': ids[i]} : null;
    }

    Future<GridEditability> editability() async {
      final e = await resolver.resolve('SELECT * FROM $table');
      expect(e, isNotNull, reason: 'the grid would be read-only');
      return e!;
    }

    test('editability resolves from the live catalog', () async {
      final e = await editability();
      expect(e.target.table, table);
      expect(e.primaryKey, ['id']);
      // Every column gets an editor, the PK included — a new row has to be able
      // to supply one where the table has no sequence.
      expect(e.editorFor('id'), isNotNull);
      expect(e.editorFor('active')!.kind.name, 'boolean');
    });

    test('a staged INSERT executes and the row comes back', () async {
      final e = await editability();

      var buf = const GridEditBuffer().addRow();
      final id = buf.inserts.single.id;
      buf = buf.setPendingValue(id, 'name', 'Barbara');
      buf = buf.setPendingValue(id, 'email', 'barbara@x.io');
      buf = buf.setPendingValue(id, 'total', 42.5);
      // `id` and `active` deliberately left unset — the engine fills them.

      final statements = await apply(buf, e, (_) => null);
      expect(statements.single, startsWith('INSERT INTO'));

      final rows = await query(
        "SELECT name, active FROM $table WHERE email = 'barbara@x.io'",
      );
      expect(rows, hasLength(1));
      expect(rows.single[0], 'Barbara');
      // The columns we left out took the sequence and the column DEFAULT —
      // proof that omitting a column is not the same as writing NULL into it.
      expect(rows.single[1], trueLiteral);
    });

    test('a boolean is encoded the way this engine spells it', () async {
      // The one value that genuinely differs across the three: TRUE on
      // Postgres, 1 on MySQL and SQLite.
      final e = await editability();
      var buf = const GridEditBuffer().addRow();
      final id = buf.inserts.single.id;
      buf = buf.setPendingValue(id, 'email', 'flag@x.io');
      buf = buf.setPendingValue(id, 'active', false);

      await apply(buf, e, (_) => null);

      final rows =
          await query("SELECT active FROM $table WHERE email = 'flag@x.io'");
      expect(rows.single.single, falseLiteral);
    });

    test('a staged DELETE removes exactly one row', () async {
      final e = await editability();
      final pk = await identities();

      await apply(const GridEditBuffer().toggleDelete(1), e, pk);

      expect(await names(), ['Ada', 'Katherine']);
    });

    test('DELETE-before-INSERT is what lets a unique key be reused', () async {
      // The ordering claim, tested against a real UNIQUE index rather than
      // asserted in a comment: drop Ada and give her address to a new row.
      final e = await editability();
      final pk = await identities();

      var buf = const GridEditBuffer().toggleDelete(0); // ada@x.io
      buf = buf.addRow({'name': 'Ada II', 'email': 'ada@x.io'});

      final statements = await apply(buf, e, pk);
      expect(statements.first, startsWith('DELETE'));
      expect(statements.last, startsWith('INSERT'));

      final rows =
          await query("SELECT name FROM $table WHERE email = 'ada@x.io'");
      expect(rows.single.single, 'Ada II');
    });

    test('all three kinds apply together, in one transaction', () async {
      final e = await editability();
      final pk = await identities();

      var buf = const GridEditBuffer().stage(const StagedEdit(
        rowIndex: 1,
        column: 'name',
        oldValue: 'Grace',
        newValue: 'Grace H.',
      ));
      buf = buf.toggleDelete(2); // Katherine
      buf = buf.addRow({'name': 'Barbara', 'email': 'barbara@x.io'});

      final statements = await apply(buf, e, pk);
      expect(statements, hasLength(3));

      expect(await names(), ['Ada', 'Grace H.', 'Barbara']);
    });

    test('a rejected statement rolls the whole batch back', () async {
      final e = await editability();

      // Two new rows, the second colliding with an existing email.
      final buf = const GridEditBuffer()
          .addRow({'name': 'Ok', 'email': 'ok@x.io'})
          .addRow({'name': 'Clash', 'email': 'ada@x.io'});
      final statements = buf.toSql(
        editability: e,
        dialect: dialect,
        pkValuesFor: (_) => null,
      );

      await session.begin();
      await expectLater(() async {
        for (final sql in statements) {
          await session.execute(sql);
        }
      }, throwsA(anything));
      await session.rollback();

      // Neither row landed — a partial apply is exactly what the transaction
      // exists to prevent.
      expect(await query("SELECT id FROM $table WHERE email = 'ok@x.io'"),
          isEmpty);
    });

    test('quotes and backslashes survive the round trip', () async {
      // Values are inlined as literals, not bound, so the review panel can show
      // the exact statement — which makes the encoder the security boundary.
      // MySQL additionally treats backslash as an escape by default.
      const nasty = r"O'Brien\'); DROP TABLE " '$table' r'; --';
      final e = await editability();

      await apply(
        const GridEditBuffer().addRow({'name': nasty, 'email': 'ob@x.io'}),
        e,
        (_) => null,
      );

      final rows =
          await query("SELECT name FROM $table WHERE email = 'ob@x.io'");
      expect(rows.single.single, nasty);
      // The table is still standing, which is the actual assertion.
      expect(await names(), hasLength(4));
    });
  },
      skip: config == null
          ? 'no live $label server — set the env var (see the file header)'
          : null);
}
