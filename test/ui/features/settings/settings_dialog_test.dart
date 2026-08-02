import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/repositories/settings_repository.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/ssl_mode.dart';
import 'package:voltquery/ui/features/settings/settings_dialog.dart';
import 'package:voltquery/ui/features/settings/settings_providers.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';

/// The settings pane applies and persists as you go — there is no OK button, so
/// "the toggle moved" and "the store has it" have to be the same event.
void main() {
  late LocalStore db;

  setUp(() => db = LocalStore.memory());
  tearDown(() => db.close());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(db)],
        child: FluentApp(
          debugShowCheckedModeBanner: false,
          home: ScaffoldPage(
            content: Consumer(builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const SettingsDialog();
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('opens on General and lists every section', (tester) async {
    await pump(tester);

    for (final section in [
      'General',
      'Editor',
      'Results',
      'Window',
      'Connections',
      'Security',
    ]) {
      expect(find.text(section), findsWidgets, reason: '$section in the rail');
    }
    expect(find.text('Prune query history'), findsOneWidget);
  });

  testWidgets('the title bar toggle persists immediately', (tester) async {
    final container = await pump(tester);

    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    expect(find.text('Show title bar'), findsOneWidget);

    await tester.tap(find.byType(ToggleSwitch));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).titleBarVisible, isFalse);
    expect((await SettingsRepository(db).read()).titleBarVisible, isFalse);
  });

  testWidgets('switching section swaps the panel', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();

    expect(find.text('Row render cap'), findsOneWidget);
    expect(find.text('Prune query history'), findsNothing);
  });

  testWidgets('the connection TLS default reaches the store', (tester) async {
    final container = await pump(tester);

    await tester.tap(find.text('Connections'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ComboBox<SslMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SslMode.verifyFull.label).last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).defaultSslMode, SslMode.verifyFull);
    expect((await SettingsRepository(db).read()).defaultSslMode,
        SslMode.verifyFull);
  });
}
