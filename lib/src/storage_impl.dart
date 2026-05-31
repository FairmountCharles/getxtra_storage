///  Library: getxtra_storage
///
///  File:    lib/src/storage_impl.dart
///
///  Desc:    This file provides the primary GetStorage compatibility class for
///           getxtra_storage. It exposes the familiar GetStorage public API while
///           delegating persistence work to the platform-specific StorageImpl
///           selected through conditional imports.
///
///           This class coordinates container instance reuse, initialization,
///           synchronous in-memory reads/writes, listener notification, and queued
///           persistence flushes to disk or browser storage.
///
///           In the long-term getxtra_storage package direction, this file is the
///           natural compatibility boundary where the historical GetStorage API can
///           remain available while a future GetXtraStorage naming layer or wrapper
///           is introduced without disrupting existing users.
///

/// Package Imports for the module
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:getxtra/utils.dart';

import 'storage/web.dart' if ( dart.library.io ) 'storage/io.dart';
import 'value.dart';

/// Instantiate GetStorage to access storage driver apis
class GetStorage {
  /// Creates or returns a cached storage container instance.
  ///
  /// The [container] name identifies the logical storage box. Calling this factory
  /// multiple times with the same container name returns the same in-memory
  /// GetStorage instance, preserving the original get_storage singleton-per-box
  /// behavior.
  ///
  /// [path] optionally overrides the platform storage location for IO platforms.
  ///
  /// [initialData] optionally seeds the container before persisted data is loaded.
  factory GetStorage( [String container = 'GetStorage', String? path, Map<String, dynamic>? initialData ]) {
    if ( _sync.containsKey( container ) ) {
      return _sync[container]!;
    } else {
      final instance = GetStorage._internal( container, path, initialData );
      _sync[container] = instance;
      return instance;
    }
  }

  /// Internal constructor used after the factory determines that a container has
  /// not already been created.
  ///
  /// This wires the abstract public GetStorage API to the platform-specific
  /// StorageImpl implementation and prepares the asynchronous initialization
  /// Future used by [init].
  GetStorage._internal( String key, [String? path, Map<String, dynamic>? initialData] ) {
    _concrete =     StorageImpl( key, path );
    _initialData =  initialData;

    initStorage = Future<bool>(
                    () async {
                      await _init();
                      return true;
                    }
                  );
  }

  /// Shared registry of named storage containers.
  ///
  /// This preserves one live GetStorage object per container name so reads,
  /// writes, listeners, and queued flushes all operate against the same
  /// in-memory state.
  static final Map<String, GetStorage> _sync = {};

  /// Microtask scheduler used to coalesce persistence flush work.
  final microtask = Microtask();

  /// Start the storage drive. It's important to use await before calling this API, or side effects will occur.
  static Future<bool> init( [String container = 'GetStorage'] ) {
    WidgetsFlutterBinding.ensureInitialized();
    return GetStorage( container ).initStorage;
  }

  /// Initializes the selected platform storage implementation.
  ///
  /// This is intentionally private because package consumers should use the
  /// static [init] API, preserving the familiar GetStorage initialization flow.
  Future<void> _init() async {
    try {
      await _concrete.init(_initialData);
    } catch (err) {
      throw err;
    }
  }

  /// Reads a value in your container with the given key.
  T? read<T>( String key ) {
    return _concrete.read(key);
  }

  /// Returns all keys currently stored in the container.
  ///
  /// The generic return type is retained for compatibility with the original
  /// GetStorage API.
  T getKeys<T>() {
    return _concrete.getKeys();
  }

  /// Returns all values currently stored in the container.
  ///
  /// The generic return type is retained for compatibility with the original
  /// GetStorage API.
  T getValues<T>() {
    return _concrete.getValues();
  }

  /// return data true if value is different of null;
  bool hasData( String key ) {
    return ( read( key ) == null ? false : true );
  }

  /// Exposes the most recent key/value mutation reported by the listenable
  /// storage subject.
  ///
  /// This is primarily used by [listenKey] to determine whether a listener
  /// should be invoked for a specific key.
  Map<String, dynamic> get changes => _concrete.subject.changes;

  /// Listen changes in your container
  VoidCallback listen( VoidCallback value ) {
    return _concrete.subject.addListener( value );
  }

  /// Tracks key-specific listener callbacks and their generated wrapper
  /// functions.
  ///
  /// This map exists to preserve the original design where listeners could be
  /// associated with callbacks and later removed.
  Map<Function, Function> _keyListeners = <Function, Function>{};

  /// Registers a listener for changes to a single storage key.
  ///
  /// When the most recent change matches [key], [callback] receives the new
  /// value for that key. The returned callback removes the listener.
  VoidCallback listenKey( String key, ValueSetter callback ) {
    final VoidCallback listen = () {
      if ( changes.keys.first == key ) {
        callback( changes[key] );
      }
    };

    _keyListeners[callback] = listen;
    return _concrete.subject.addListener( listen );
  }

  // /// Remove listen of your container
  // void removeKeyListen(Function(Map<String, dynamic>) callback) {
  //   _concrete.subject.removeListener(_keyListeners[callback]);
  // }

  // /// Remove listen of your container
  // void removeListen(void Function() listener) {
  //   _concrete.subject.removeListener(listener);
  // }

  /// Write data on your container
  Future<void> write( String key, dynamic value ) async {
    writeInMemory( key, value );
    // final _encoded = json.encode(value);
    // await _concrete.write(key, json.decode(_encoded));

    return _tryFlush();
  }

  /// Writes data only to the in-memory container.
  ///
  /// This updates the live subject immediately and notifies listeners, but does
  /// not directly flush to persistent storage. Callers that need persistence
  /// should use [write] or call [save] afterward.
  void writeInMemory( String key, dynamic value ) {
    _concrete.write( key, value );
  }

  /// Write data on your only if data is null
  Future<void> writeIfNull( String key, dynamic value ) async {
    if ( read( key ) != null) return;
    return write( key, value );
  }

  /// remove data from container by key
  Future<void> remove( String key ) async {
    _concrete.remove( key );
    return _tryFlush();
  }

  /// clear all data on your container
  Future<void> erase() async {
    _concrete.clear();
    return _tryFlush();
  }

  /// Persists the current in-memory container state.
  ///
  /// This is useful after one or more [writeInMemory] calls when the caller wants
  /// to explicitly flush the accumulated state.
  Future<void> save() async {
    return _tryFlush();
  }

  /// Schedules a persistence flush through the microtask coordinator.
  ///
  /// Multiple writes in the same microtask window can be collapsed into a queued
  /// flush operation, preserving the fast synchronous read/write feel of
  /// GetStorage while still backing up state asynchronously.
  Future<void> _tryFlush() async {
    return microtask.exec(_addToQueue);
  }

  /// Adds the actual flush operation to the GetQueue.
  ///
  /// GetQueue serializes asynchronous work so persistence writes are performed
  /// in order.
  Future _addToQueue() {
    return queue.add( _flush );
  }

  /// Flushes the current in-memory state to the active platform storage backend.
  Future<void> _flush() async {
    try {
      await _concrete.flush();
    } catch ( e ) {
      rethrow;
    }
    return;
  }

  /// Platform-specific storage implementation selected by conditional import.
  late StorageImpl _concrete;

  /// Queue used to serialize storage flush operations.
  GetQueue queue = GetQueue();

  /// listenable of container
  ValueStorage<Map<String, dynamic>> get listenable => _concrete.subject;

  /// Start the storage drive. Important: use await before calling this api, or side effects will happen.
  late Future<bool> initStorage;

  /// Optional seed data supplied when the container is first constructed.
  Map<String, dynamic>? _initialData;
}

/// Simple microtask gate used to avoid scheduling redundant flush callbacks.
class Microtask {
  /// Tracks the most recently completed microtask version.
  int _version =    0;

  /// Tracks whether a microtask has already been scheduled for the current
  /// version.
  int _microtask =  0;

  /// Schedules [callback] to run in a microtask if one is not already pending.
  ///
  /// This keeps rapid consecutive writes from immediately stacking duplicate
  /// flush scheduling work in the same event-loop turn.
  void exec( Function callback ) {
    if ( _microtask == _version ) {

      _microtask++;

      scheduleMicrotask(
        () {
          _version++;
          _microtask = _version;
          callback();
        }
      );
    }
  }
}

/// Callback signature retained for compatibility with the original storage API.
typedef KeyCallback = Function( String );
