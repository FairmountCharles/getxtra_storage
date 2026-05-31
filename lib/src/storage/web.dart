///  Library: getxtra_storage
///
///  File:    lib/src/value.dart
///
///  Desc:    This file provides a definition for the ValueStorage class, which
///           provides value storage services into the package.
///

/// Package Imports for the module
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import '../value.dart';

// Web Storage API bindings using js_interop
@JS('localStorage.getItem')
external String? _getItem( String key );

@JS( 'localStorage.setItem' )
external void _setItem( String key, String value );

@JS( 'localStorage.removeItem' )
external void _removeItem( String key );

class StorageImpl {
  StorageImpl( this.fileName, [this.path] );

  final String? path;
  final String fileName;

  ValueStorage<Map<String, dynamic>> subject = ValueStorage<Map<String, dynamic>>( <String, dynamic>{} );

  void clear() {
    _removeItem( fileName );
    subject.value.clear();

    subject
      ..value.clear()
      ..changeValue( "", null );
  }

  Future<bool> _exists() async {
    return _getItem( fileName ) != null;
  }

  Future<void> flush() {
    return _writeToStorage( subject.value );
  }

  T? read<T>( String key ) {
    return subject.value[key] as T?;
  }

  T getKeys<T>() {
    return subject.value.keys as T;
  }

  T getValues<T>() {
    return subject.value.values as T;
  }

  Future<void> init( [Map<String, dynamic>? initialData] ) async {

    subject.value = initialData ?? <String, dynamic>{};

    if ( await _exists() ) {
      await _readFromStorage();
    } else {
      await _writeToStorage( subject.value );
    }
    return;
  }

  void remove( String key ) {
    subject
      ..value.remove( key )
      ..changeValue( key, null );
  }

  void write( String key, dynamic value ) {
    subject
      ..value[key] = value
      ..changeValue( key, value );
  }

  Future<void> _writeToStorage( Map<String, dynamic> data ) async {
    _setItem( fileName, json.encode( subject.value ) );
  }

  Future<void> _readFromStorage() async {
    final dataFromLocal = _getItem( fileName );
    if ( dataFromLocal != null ) {
      subject.value = json.decode( dataFromLocal ) as Map<String, dynamic>;
    } else {
      await _writeToStorage( <String, dynamic>{} );
    }
  }
}
