// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider
    extends
        $FunctionalProvider<
          SettingsRepository,
          SettingsRepository,
          SettingsRepository
        >
    with $Provider<SettingsRepository> {
  SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'0401f4c697bdf341e7176c33d90ba678362b24ea';

/// App-wide settings, synchronously readable.
///
/// A plain [AppSettings] rather than an `AsyncValue` because nearly every reader
/// is a widget that needs *a* value to render with — an editor can't wait on a
/// font size. It starts at the defaults and the stored values land a tick
/// later; anything that must not flicker on startup (the window title bar)
/// reads the repository directly before `runApp` instead.

@ProviderFor(Settings)
final settingsProvider = SettingsProvider._();

/// App-wide settings, synchronously readable.
///
/// A plain [AppSettings] rather than an `AsyncValue` because nearly every reader
/// is a widget that needs *a* value to render with — an editor can't wait on a
/// font size. It starts at the defaults and the stored values land a tick
/// later; anything that must not flicker on startup (the window title bar)
/// reads the repository directly before `runApp` instead.
final class SettingsProvider extends $NotifierProvider<Settings, AppSettings> {
  /// App-wide settings, synchronously readable.
  ///
  /// A plain [AppSettings] rather than an `AsyncValue` because nearly every reader
  /// is a widget that needs *a* value to render with — an editor can't wait on a
  /// font size. It starts at the defaults and the stored values land a tick
  /// later; anything that must not flicker on startup (the window title bar)
  /// reads the repository directly before `runApp` instead.
  SettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsHash();

  @$internal
  @override
  Settings create() => Settings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$settingsHash() => r'290183aa591b0c785929e8e0296dbe4bccee2ca9';

/// App-wide settings, synchronously readable.
///
/// A plain [AppSettings] rather than an `AsyncValue` because nearly every reader
/// is a widget that needs *a* value to render with — an editor can't wait on a
/// font size. It starts at the defaults and the stored values land a tick
/// later; anything that must not flicker on startup (the window title bar)
/// reads the repository directly before `runApp` instead.

abstract class _$Settings extends $Notifier<AppSettings> {
  AppSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppSettings, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppSettings, AppSettings>,
              AppSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(uiStateRepository)
final uiStateRepositoryProvider = UiStateRepositoryProvider._();

final class UiStateRepositoryProvider
    extends
        $FunctionalProvider<
          UiStateRepository,
          UiStateRepository,
          UiStateRepository
        >
    with $Provider<UiStateRepository> {
  UiStateRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uiStateRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uiStateRepositoryHash();

  @$internal
  @override
  $ProviderElement<UiStateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UiStateRepository create(Ref ref) {
    return uiStateRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UiStateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UiStateRepository>(value),
    );
  }
}

String _$uiStateRepositoryHash() => r'b15e3154ce301492095ab68b401ec08b17909276';

/// Installed monospace families for the font picker. **keepAlive**: shelling
/// out to fontconfig once per app run is fine; once per dialog open is not.

@ProviderFor(monospaceFonts)
final monospaceFontsProvider = MonospaceFontsProvider._();

/// Installed monospace families for the font picker. **keepAlive**: shelling
/// out to fontconfig once per app run is fine; once per dialog open is not.

final class MonospaceFontsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Installed monospace families for the font picker. **keepAlive**: shelling
  /// out to fontconfig once per app run is fine; once per dialog open is not.
  MonospaceFontsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monospaceFontsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monospaceFontsHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return monospaceFonts(ref);
  }
}

String _$monospaceFontsHash() => r'f4bc1b7f11bb4f7e4a00f66782723fa3fa495036';
