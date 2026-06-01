///  Library: getxtra_storage
///
///  File:    test/helpers/storage_test_helper.dart
///
///  Desc:    Provides reusable test helpers for getxtra_storage regression
///           tests. These helpers centralize path_provider mocking, temporary
///           test directory creation, and cleanup so individual tests can focus
///           on storage behavior rather than Flutter plugin setup.
///

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared path_provider channel used by path_provider on supported Flutter
/// test platforms.
const MethodChannel pathProviderChannel =
    MethodChannel( 'plugins.flutter.io/path_provider' );

/// Creates a deterministic temporary directory for a single test run.
Future<Directory> createStorageTestDirectory( String name ) async {
  final root = Directory.systemTemp.createTempSync( 'getxtra_storage_test_' );
  final dir = Directory( '${root.path}${Platform.pathSeparator}$name' );

  if ( !dir.existsSync() ) {
    dir.createSync( recursive: true );
  }

  return dir;
}

/// Mocks path_provider so getApplicationDocumentsDirectory() returns [dir].
///
/// This is required for IO-backed tests because getxtra_storage resolves its
/// default storage location through path_provider.
void mockApplicationDocumentsDirectory( Directory dir ) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    pathProviderChannel,
    ( MethodCall? methodCall ) async {
      if ( methodCall?.method == 'getApplicationDocumentsDirectory' ) {
        return dir.path;
      }

      return null;
    },
  );
}

/// Clears the path_provider mock after a test suite finishes.
void clearPathProviderMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    pathProviderChannel,
    null,
  );
}

/// Deletes [dir] recursively if it still exists.
Future<void> deleteStorageTestDirectory( Directory dir ) async {
  if ( dir.existsSync() ) {
    await dir.delete( recursive: true );
  }
}

/// Resolves the primary storage file used by the IO backend.
File storageFile(
  Directory dir, {
  String fileName = 'GetStorage',
}) {
  return File( '${dir.path}${Platform.pathSeparator}$fileName.gs' );
}

/// Resolves the backup storage file used by the IO backend.
File storageBackupFile(
  Directory dir, {
  String fileName = 'GetStorage',
}) {
  return File( '${dir.path}${Platform.pathSeparator}$fileName.bak' );
}
