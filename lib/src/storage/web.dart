///  Library: getxtra_storage
///
///  File:    lib/src/storage/web.dart
///
///  Desc:    This file provides the web storage implementation used by
///           getxtra_storage when running in browser-based Flutter targets.
///
///           Unlike the legacy get_storage web implementation, which relied on
///           dart:html, this implementation uses dart:js_interop bindings to
///           communicate directly with the browser Web Storage API. This keeps
///           the package aligned with modern Dart and Flutter web guidance and
///           supports the package goal of improved WebAssembly compatibility.
///
///           Data is stored in the browser's localStorage system using the
///           container fileName as the storage key. The in-memory subject remains
///           the immediate source of truth for reads and listener notifications,
///           while flush() serializes the current map state into localStorage.
///
///           This implementation intentionally mirrors the IO storage contract
///           so the higher-level GetStorage compatibility API can remain
///           platform-neutral.
///

/// Package Imports for the module
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import '../value.dart';

/// Web Storage API binding for localStorage.getItem().
///
/// Returns the stored string value for [key], or null when no browser storage
/// entry exists.
@JS( 'localStorage.getItem' )
external String? _getItem( String key );

/// Web Storage API binding for localStorage.setItem().
///
/// Stores [value] in browser localStorage under [key].
@JS( 'localStorage.setItem' )
external void _setItem( String key, String value );

/// Web Storage API binding for localStorage.removeItem().
///
/// Removes the browser localStorage entry associated with [key].
@JS( 'localStorage.removeItem' )
external void _removeItem( String key );

/// Platform-specific storage implementation for web targets.
///
/// This class is selected by conditional import from storage_impl.dart when the
/// package is compiled for web. It provides the same public storage surface as
/// the IO implementation while persisting data to browser localStorage.
class StorageImpl {
  /// Creates a web storage implementation for a named container.
  ///
  /// [fileName] is used as the localStorage key.
  ///
  /// [path] is accepted for API symmetry with IO storage, but is not used by the
  /// browser implementation.
  StorageImpl( this.fileName, [this.path] );

  /// Optional path retained for constructor compatibility with IO storage.
  ///
  /// Browser localStorage does not support file-system paths, so this value is
  /// currently unused on web.
  final String? path;

  /// Storage container name.
  ///
  /// This value becomes the localStorage key used to persist the encoded map.
  final String fileName;

  /// Reactive in-memory storage subject.
  ///
  /// This map is the immediate source of truth for reads, writes, removals, and
  /// listener notifications. Persistence to localStorage happens through flush().
  ValueStorage<Map<String, dynamic>> subject = ValueStorage<Map<String, dynamic>>( <String, dynamic>{} );

  /// Clears the current container from browser storage and memory.
  ///
  /// The localStorage entry is removed, the in-memory map is cleared, and a
  /// change notification is emitted so listeners can react to the erase.
  void clear() {
    _removeItem( fileName );
    subject.value.clear();

    subject
      ..value.clear()
      ..changeValue( "", null );
  }

  /// Returns true when a localStorage entry exists for this container.
  Future<bool> _exists() async {
    return _getItem( fileName ) != null;
  }

  /// Persists the current in-memory subject value to browser localStorage.
  Future<void> flush() {
    return _writeToStorage( subject.value );
  }

  /// Reads a value from the in-memory container.
  ///
  /// Reads are intentionally served from memory rather than localStorage so they
  /// remain synchronous and consistent with the original GetStorage behavior.
  T? read<T>( String key ) {
    return subject.value[key] as T?;
  }

  /// Returns the keys currently present in the in-memory container.
  ///
  /// The generic return shape is preserved for compatibility with the original
  /// GetStorage API.
  T getKeys<T>() {
    return subject.value.keys as T;
  }

  /// Returns the values currently present in the in-memory container.
  ///
  /// The generic return shape is preserved for compatibility with the original
  /// GetStorage API.
  T getValues<T>() {
    return subject.value.values as T;
  }

  /// Initializes the web storage container.
  ///
  /// [initialData] seeds the in-memory map before persisted browser data is
  /// loaded. If an existing localStorage entry is present, that persisted data
  /// replaces the initial value. Otherwise, the initial map is written to
  /// localStorage to establish the container.
  Future<void> init( [Map<String, dynamic>? initialData] ) async {

    subject.value = initialData ?? <String, dynamic>{};

    if ( await _exists() ) {
      await _readFromStorage();
    } else {
      await _writeToStorage( subject.value );
    }
    return;
  }

  /// Removes a key from the in-memory container.
  ///
  /// Persistence is not performed directly here. The higher-level GetStorage API
  /// schedules a flush after removals, preserving platform-neutral behavior.
  void remove( String key ) {
    subject
      ..value.remove( key )
      ..changeValue( key, null );
  }

  /// Writes a key/value pair into the in-memory container.
  ///
  /// Persistence is not performed directly here. The higher-level GetStorage API
  /// schedules a flush after writes, allowing writes to remain immediately
  /// readable while disk/browser persistence happens asynchronously.
  void write( String key, dynamic value ) {
    subject
      ..value[key] = value
      ..changeValue( key, value );
  }

  /// Serializes and writes the container map to browser localStorage.
  ///
  /// The [data] parameter is retained to match the storage implementation
  /// contract, but the current subject value is encoded to ensure the most recent
  /// in-memory state is persisted.
  Future<void> _writeToStorage( Map<String, dynamic> data ) async {
    _setItem( fileName, json.encode( subject.value ) );
  }

  /// Reads and decodes the container map from browser localStorage.
  ///
  /// If no localStorage entry exists, an empty container is written so future
  /// reads and flushes have a known storage entry.
  Future<void> _readFromStorage() async {
    final dataFromLocal = _getItem( fileName );
    if ( dataFromLocal != null ) {
      subject.value = json.decode( dataFromLocal ) as Map<String, dynamic>;
    } else {
      await _writeToStorage( <String, dynamic>{} );
    }
  }
}
