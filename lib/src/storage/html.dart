///  Library: getxtra_storage
///
///  File:    lib/src/storage/html.dart
///
///  Desc:    This file provides the legacy dart:html-based browser storage
///           implementation inherited from the original get_storage web
///           backend.
///
///           Functionally, this implementation performs the same role as
///           storage/web.dart: it stores the full container map in the browser's
///           localStorage system using the container fileName as the storage
///           key.
///
///           Reads and writes are performed against the in-memory ValueStorage
///           subject first, preserving the original GetStorage behavior where
///           reads are immediate and persistence is flushed separately.
///
///           This file is retained as a compatibility baseline and migration
///           reference. For modern Flutter web and WebAssembly compatibility,
///           storage/web.dart should be preferred because it uses dart:js_interop
///           instead of the deprecated dart:html library.
///
///           Expected future direction:
///
///             • Keep this file only if a legacy HTML backend is still needed.
///             • Prefer storage/web.dart for active web support.
///             • Avoid routing new code through dart:html.
///             • Remove this file once compatibility requirements are confirmed.
///

/// Package Imports for the module
import 'dart:async';
import 'dart:convert';

// Legacy browser API import.
//
// dart:html is deprecated for modern Flutter web targets and is not the desired
// long-term implementation path for getxtra_storage. This ignore is retained
// only so the legacy implementation can remain available as a reference or
// fallback while compatibility is evaluated.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../value.dart';

/// Legacy browser storage implementation backed by window.localStorage.
///
/// This class mirrors the platform contract used by the IO and modern web
/// implementations so the higher-level GetStorage API can remain unchanged.
class StorageImpl {

  /// Creates a browser storage implementation for a named container.
  ///
  /// [fileName] is used as the localStorage key.
  ///
  /// [path] is accepted for API symmetry with IO storage, but browser
  /// localStorage does not use filesystem paths.
  StorageImpl( this.fileName, [this.path] );

  /// Returns the browser localStorage object.
  ///
  /// This is the dart:html equivalent of the js_interop calls used in
  /// storage/web.dart.
  html.Storage get localStorage => html.window.localStorage;

  /// Optional path retained for compatibility with the shared StorageImpl
  /// constructor shape.
  ///
  /// This value is unused by the browser implementation.
  final String? path;

  /// Logical container name.
  ///
  /// On web, this becomes the key under which the encoded storage map is saved
  /// in browser localStorage.
  final String fileName;

  /// Reactive in-memory storage subject.
  ///
  /// The subject contains the live map used for synchronous reads, writes,
  /// removals, and listener notifications.
  ValueStorage<Map<String, dynamic>> subject =
      ValueStorage<Map<String, dynamic>>( <String, dynamic>{} );

  /// Clears the current container from browser localStorage and memory.
  ///
  /// A change notification is emitted after the in-memory map is cleared.
  void clear() {
    localStorage.remove( fileName );
    subject.value.clear();

    subject
      ..value.clear()
      ..changeValue( "", null );
  }

  /// Returns true when localStorage already contains this container.
  Future<bool> _exists() async {
    return localStorage.containsKey( fileName );
  }

  /// Persists the current in-memory subject value to browser localStorage.
  Future<void> flush() {
    return _writeToStorage( subject.value );
  }

  /// Reads a value from the in-memory container.
  ///
  /// Reads intentionally do not query localStorage directly. The storage file is
  /// loaded during init(), after which memory is treated as the source of truth.
  T? read<T>( String key ) {
    return subject.value[key] as T?;
  }

  /// Returns all keys currently present in the in-memory container.
  T getKeys<T>() {
    return subject.value.keys as T;
  }

  /// Returns all values currently present in the in-memory container.
  T getValues<T>() {
    return subject.value.values as T;
  }

  /// Initializes the browser storage container.
  ///
  /// If localStorage already contains this container, the persisted JSON is
  /// loaded into memory. Otherwise, [initialData] is written as the initial
  /// container value.
  Future<void> init( [Map<String, dynamic>? initialData] ) async {

    subject.value = initialData ?? <String, dynamic>{};

    if ( await _exists() ) {
      await _readFromStorage();
    } else {
      await _writeToStorage( subject.value );
    }
    return;
  }

  /// Removes a key from the in-memory container and notifies listeners.
  ///
  /// Persistence is intentionally left to the higher-level flush pipeline.
  void remove( String key ) {
    subject
      ..value.remove( key )
      ..changeValue( key, null );
    //  return _writeToStorage(subject.value);
  }

  /// Writes a key/value pair into the in-memory container and notifies listeners.
  ///
  /// Persistence is intentionally left to the higher-level flush pipeline.
  void write( String key, dynamic value ) {
    subject
      ..value[key] = value
      ..changeValue( key, value );
    //return _writeToStorage(subject.value);
  }

  // void writeInMemory(String key, dynamic value) {

  // }

  /// Serializes and writes the current container map to localStorage.
  ///
  /// The [data] parameter is retained for implementation-contract symmetry, but
  /// the current subject value is encoded so the latest in-memory state is
  /// persisted.
  Future<void> _writeToStorage( Map<String, dynamic> data ) async {
    localStorage.update( 
      fileName,
      ( val ) => json.encode( subject.value ),
      ifAbsent: () => json.encode( subject.value )
    );
  }

  /// Reads the stored JSON container from localStorage and loads it into memory.
  ///
  /// If the container cannot be found, an empty container is written.
  Future<void> _readFromStorage() async {
    final dataFromLocal = localStorage.entries.firstWhereOrNull(
                            ( value ) => value.key == fileName,
                          );
    if ( dataFromLocal != null ) {
      subject.value = json.decode( dataFromLocal.value ) as Map<String, dynamic>;
    } else {
      await _writeToStorage( <String, dynamic>{} );
    }
  }
}

/// Small compatibility helper for nullable firstWhere behavior.
///
/// This avoids throwing when no matching localStorage entry is found.
extension FirstWhereExt<T> on Iterable<T> {

  /// Returns the first element that satisfies [test], or null if none match.
  T? firstWhereOrNull( bool Function( T element ) test ) {
    for ( var element in this ) {
      if ( test( element ) ) return element;
    }
    return null;
  }
}
