# Testing getxtra_storage

`getxtra_storage` is a memory-first storage package with platform-specific persistence backends.

The public API should behave the same across platforms, while the persistence layer differs by target:

- IO platforms use files under the application documents directory.
- Web and WASM use browser `localStorage` through `dart:js_interop`.

## Test Goals

The regression suite should protect the compatibility contract inherited from GetStorage:

- `init`
- `read`
- `write`
- `writeIfNull`
- `remove`
- `erase`
- `save`
- `getKeys`
- `getValues`
- named containers
- `listen`
- `listenKey`
- `ReadWriteValue`
- backup recovery on IO platforms
- JSON-compatible value examples

## Why path_provider Must Be Mocked

On IO platforms, `getxtra_storage` resolves its storage directory through `path_provider`.

In Flutter unit tests, plugin calls do not automatically resolve to native platform code. This means tests that call `GetStorage.init()` need a mocked method channel for:

```text
plugins.flutter.io/path_provider
```

The helper in `test/helpers/storage_test_helper.dart` provides:

```dart
mockApplicationDocumentsDirectory( testDirectory );
```

This causes `getApplicationDocumentsDirectory()` to return a deterministic temporary directory during tests.

## Recommended Test Layout

```text
test/
  getxtra_storage_regression_test.dart
  helpers/
    storage_test_helper.dart
  utils/
    list_equality.dart
```

## Running Tests

```bash
flutter test
```

## Running Analyze

```bash
dart analyze
```

## Web and WASM Validation

The regular unit test suite primarily validates Dart and IO behavior.

For web and WASM compatibility, also run:

```bash
flutter build web --release
flutter build web --release --wasm
```

The important guarantee is that the package should not import `dart:html` from the active web backend. The active web backend should use `dart:js_interop`.

## Adding New Tests

When adding behavior, prefer testing through the public package import:

```dart
import 'package:getxtra_storage/getxtra_storage.dart';
```

Avoid importing private implementation files unless the test specifically targets internal behavior.

## Test Isolation

Use unique container names when testing container behavior.

Use `erase()` in `setUp()` for the default container:

```dart
setUp(() async {
  await GetStorage.init();
  await GetStorage().erase();
});
```

For IO persistence tests, prefer a temporary directory and mocked `path_provider` rather than writing into the real application documents directory.

## JSON-Compatible Values

The test suite includes examples for:

- primitive values
- maps
- lists
- custom objects via `toJson()` / `fromJson()`
- custom objects via encoded JSON strings
- `DateTime` via ISO-8601 strings
- enums via `.name`

These tests double as executable documentation for supported value types.
