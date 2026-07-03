///  Library: getxtra_storage
///
///  File:    lib/src/storage/io.dart
///
///  Desc:    This file provides the file-system-backed storage implementation
///           used by getxtra_storage on IO platforms, including Android, iOS,
///           macOS, Windows, Linux, and other Dart VM environments.
///
///           This implementation follows the original GetStorage design:
///
///             • Maintain all active data in memory.
///             • Provide immediate synchronous reads.
///             • Persist changes asynchronously to disk.
///             • Maintain a backup copy for recovery.
///
///           Storage containers are serialized as JSON and written to files
///           within the application's documents directory (or an optionally
///           supplied custom path).
///
///           The primary storage file uses the ".gs" extension while a backup
///           copy is maintained using the ".bak" extension. If corruption is
///           detected while reading the primary file, the backup file is used
///           to recover container contents whenever possible.
///
///           This implementation intentionally mirrors the web storage contract
///           so higher-level GetStorage APIs remain platform-neutral.
///
///           This class is the primary persistence engine for mobile and desktop
///           platforms and is expected to remain compatible with future Flutter,
///           Dart, and GetXtra releases.
///

/// Package Imports for the module
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:getxtra/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:getxtra_storage/src/value.dart';

/// Platform-specific storage implementation for file-system-backed targets.
///
/// This implementation is selected through conditional imports whenever the
/// application is running on an IO platform rather than the browser.
class StorageImpl {

  /// Creates a storage container implementation.
  ///
  /// [fileName] becomes the logical storage container name and ultimately
  /// determines the backing file names.
  ///
  /// [path] may be supplied to override the default application documents
  /// directory.
  StorageImpl( this.fileName, [this.path] );

  /// Optional custom storage path.
  ///
  /// If omitted, the application documents directory supplied by
  /// path_provider is used.
  final String? path;

  /// Logical container name.
  ///
  /// This value becomes the base name of the backing ".gs" and ".bak" files.
  final String fileName;

  /// Reactive in-memory storage subject.
  ///
  /// This map is the immediate source of truth for all reads and writes.
  /// Persistence to disk occurs through flush() operations.
  final ValueStorage<Map<String, dynamic>> subject =
      ValueStorage<Map<String, dynamic>>( <String, dynamic>{} );

  /// Cached file handle used for efficient repeated storage operations.
  RandomAccessFile? _randomAccessfile;

  /// Clears all values from the in-memory container.
  ///
  /// Persistence occurs later through the standard flush pipeline.
  ///
  /// A change notification is emitted so listeners are informed that the
  /// container contents have been erased.
  Future<void> clear() async {
    subject
      ..value.clear()
      ..changeValue( "", null );
  }

  /// Permanently deletes both the primary and backup storage files.
  ///
  /// This operation removes all persisted storage associated with the
  /// container.
  Future<void> deleteBox() async {
    final box = await _fileDb( isBackup: false );
    final backup = await _fileDb( isBackup: true );
    await Future.wait( [box.delete(), backup.delete()] );
  }

  /// Persists the current in-memory container to disk.
  ///
  /// The current map is serialized to JSON and written to the primary storage
  /// file. The file is truncated to ensure stale data from previous writes
  /// cannot remain at the end of the file.
  ///
  /// After the primary write completes, a backup copy is generated.
  Future<void> flush() async {

    final buffer = utf8.encode( json.encode( subject.value ) );
    final length = buffer.length;

    RandomAccessFile file = await _getRandomFile();

    _randomAccessfile = await file.lock();
    _randomAccessfile = await _randomAccessfile!.setPosition( 0 );
    _randomAccessfile = await _randomAccessfile!.writeFrom( buffer );
    _randomAccessfile = await _randomAccessfile!.truncate( length );
    _randomAccessfile = await file.unlock();

    _madeBackup();
  }

  /// Creates or updates the backup copy of the container.
  ///
  /// The backup file provides recovery support when the primary file becomes
  /// corrupted or unreadable.
  void _madeBackup() {
    _getFile( true ).then(
      ( value ) => value.writeAsString(
                      json.encode( subject.value ),
                      flush: true,
                    ),
    );
  }

  /// Reads a value from the in-memory container.
  ///
  /// Reads are intentionally served from memory rather than disk so that
  /// access remains effectively instantaneous.
  T? read<T>( String key ) {
    return subject.value[key] as T?;
  }

  /// Returns all currently stored keys.
  ///
  /// The generic return type is preserved for compatibility with the original
  /// GetStorage API.
  T getKeys<T>() {
    return subject.value.keys as T;
  }

  /// Returns all currently stored values.
  ///
  /// The generic return type is preserved for compatibility with the original
  /// GetStorage API.
  T getValues<T>() {
    return subject.value.values as T;
  }

  /// Initializes the storage container.
  ///
  /// If a storage file already exists, its contents are loaded into memory.
  ///
  /// If no file exists or the file is empty, the current in-memory state is
  /// persisted to establish the container.
  Future<void> init( [Map<String, dynamic>? initialData] ) async {

    subject.value = initialData ?? <String, dynamic>{};

    RandomAccessFile file = await _getRandomFile();

    return file.lengthSync() == 0 ? flush() : _readFile();
  }

  /// Removes a key from the in-memory container.
  ///
  /// Persistence occurs later through the standard flush pipeline.
  void remove( String key ) {
    subject
      ..value.remove( key )
      ..changeValue( key, null );
  }

  /// Writes a value into the in-memory container.
  ///
  /// Persistence occurs later through the standard flush pipeline.
  void write( String key, dynamic value ) {
    subject
      ..value[key] = value
      ..changeValue( key, value );
  }

  /// Reads and deserializes the primary storage file.
  ///
  /// If corruption is detected, the backup file is used as a recovery source.
  Future<void> _readFile() async {
    try {

      RandomAccessFile file = await _getRandomFile();

      file = await file.setPosition( 0 );

      final buffer =  Uint8List( await file.length() );

      await file.readInto( buffer );

      subject.value = json.decode( utf8.decode( buffer ) );

    } catch ( e ) {

      Get.log( 'Corrupted box, recovering backup file', isError: true );

      final file = await _getFile( true );

      final content = await file.readAsString()
                              ..trim();

      if ( content.isEmpty ) {

        subject.value = {};

      } else {

        try {

          subject.value =
              ( json.decode(content) as Map<String, dynamic>? ) ?? {};

        } catch ( e ) {

          Get.log( 'Can not recover Corrupted box', isError: true );

          subject.value = {};
        }
      }

      await flush();
    }
  }

  /// Returns the active random-access file handle.
  ///
  /// The file handle is cached so repeated flush operations avoid repeatedly
  /// opening and closing the same file.
  Future<RandomAccessFile> _getRandomFile() async {

    if (_randomAccessfile != null) return _randomAccessfile!;

    final fileDb = await _getFile(false);

    _randomAccessfile = await fileDb.open(mode: FileMode.append);

    return _randomAccessfile!;
  }

  /// Returns a File object for either the primary or backup file.
  ///
  /// Missing files are automatically created.
  Future<File> _getFile( bool isBackup ) async {

    final fileDb = await _fileDb( isBackup: isBackup );

    if ( !fileDb.existsSync() ) {
      fileDb.createSync( recursive: true );
    }

    return fileDb;
  }

  /// Resolves the actual file path for the requested storage file.
  Future<File> _fileDb({ required bool isBackup }) async {

    final dir =   await _getImplicitDir();
    final newpath = await _getPath( isBackup, path ?? dir.path );
    final file = File( newpath );

    return file;
  }

  /// Returns the application's default documents directory.
  ///
  /// This location is supplied by the path_provider package and provides a
  /// platform-appropriate persistent storage location.
  Future<Directory> _getImplicitDir() async {
    try {
      return getApplicationDocumentsDirectory();
    } catch ( err ) {
      rethrow;
    }
  }

  /// Constructs the platform-specific storage path.
  ///
  /// Primary files use:
  ///
  ///   container.gs
  ///
  /// Backup files use:
  ///
  ///   container.bak
  ///
  /// The platform-specific path separator is selected automatically.
  Future<String> _getPath( bool isBackup, String? path ) async {

    final isWindows = GetPlatform.isWindows;
    final separator = isWindows ? '\\' : '/';

    return  isBackup
              ? '$path$separator$fileName.bak'
              : '$path$separator$fileName.gs';
  }
}
