///  Library: getxtra_storage
///
///  File:    test/getxtra_storage_regression_test.dart
///
///  Desc:    Provides regression coverage for the public GetStorage-compatible
///           API exposed by getxtra_storage. These tests intentionally focus on
///           behavior inherited from get_storage so future modernization work
///           can proceed without accidentally breaking compatibility.
///

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:getxtra_storage/getxtra_storage.dart';

import 'helpers/storage_test_helper.dart';
import 'utils/list_equality.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDirectory;

  setUpAll(() async {
    testDirectory = await createStorageTestDirectory( 'documents' );
    mockApplicationDocumentsDirectory( testDirectory );
  });

  tearDownAll(() async {
    clearPathProviderMock();
    await deleteStorageTestDirectory( testDirectory );
  });

  setUp(() async {
    await GetStorage.init();
    await GetStorage().erase();
  });

  group( 'GetStorage core API', () {
    test( 'initializes default container', () async {
      final initialized = await GetStorage.init();

      expect( initialized, isTrue );
      expect( GetStorage(), same( GetStorage() ) );
    });

    test( 'writes and reads primitive JSON-compatible values', () async {
      final box = GetStorage();

      await box.write( 'string', 'value' );
      await box.write( 'int', 1 );
      await box.write( 'double', 1.5 );
      await box.write( 'bool', true );
      await box.write( 'list', <dynamic>[1, 'two', false] );
      await box.write( 'map', <String, dynamic>{ 'nested': 'value' });

      expect( box.read<String>( 'string' ), 'value' );
      expect( box.read<int>( 'int' ), 1 );
      expect( box.read<double>( 'double' ), 1.5 );
      expect( box.read<bool>( 'bool' ), true );
      expect( box.read<List<dynamic>>( 'list' ), <dynamic>[1, 'two', false] );
      expect(
        box.read<Map<String, dynamic>>( 'map' ),
        <String, dynamic>{ 'nested': 'value' },
      );
    });

    test( 'hasData reports whether a key has a non-null value', () async {
      final box = GetStorage();

      expect( box.hasData( 'missing' ), isFalse );

      await box.write( 'present', 'value' );

      expect( box.hasData( 'present' ), isTrue );
    });

    test( 'writeIfNull only writes when no value exists', () async {
      final box = GetStorage();

      await box.writeIfNull( 'key', 'first' );
      await box.writeIfNull( 'key', 'second' );

      expect( box.read<String>( 'key' ), 'first' );
    });

    test( 'remove deletes a key from memory and persistence', () async {
      final box = GetStorage();

      await box.write( 'key', 'value' );
      expect( box.read<String>( 'key' ), 'value' );

      await box.remove( 'key' );
      expect( box.read<String>( 'key' ), isNull );
    });

    test( 'erase clears all values from the container', () async {
      final box = GetStorage();

      await box.write( 'a', 1 );
      await box.write( 'b', 2 );

      await box.erase();

      expect( box.read<int>( 'a' ), isNull );
      expect( box.read<int>( 'b' ), isNull );
      expect( box.getKeys<Iterable>().toList(), isEmpty );
    });

    test( 'getKeys and getValues preserve insertion order for map contents', () async {
      final box = GetStorage();
      final eq = const ListEquality<dynamic>();

      expect( eq.equals( box.getKeys<Iterable>().toList(), <dynamic>[] ), true );
      expect( eq.equals( box.getValues<Iterable>().toList(), <dynamic>[] ), true );

      await box.write( 'key1', 1 );
      await box.write( 'key2', 'a' );
      await box.write( 'key3', 3.0 );

      expect(
        eq.equals( box.getKeys<Iterable>().toList(), <dynamic>['key1', 'key2', 'key3'] ),
        true,
      );
      expect(
        eq.equals( box.getValues<Iterable>().toList(), <dynamic>[1, 'a', 3.0] ),
        true,
      );
    });
  });

  group( 'containers', () {
    test( 'same container name returns the same instance', () async {
      await GetStorage.init( 'sharedContainer' );

      final first = GetStorage( 'sharedContainer' );
      final second = GetStorage( 'sharedContainer' );

      expect( identical( first, second ), isTrue );
    });

    test( 'different containers maintain independent data', () async {
      await GetStorage.init( 'containerA' );
      await GetStorage.init( 'containerB' );

      final a = GetStorage( 'containerA' );
      final b = GetStorage( 'containerB' );

      await a.erase();
      await b.erase();

      await a.write( 'key', 'a' );
      await b.write( 'key', 'b' );

      expect( a.read<String>( 'key' ), 'a' );
      expect( b.read<String>( 'key' ), 'b' );
    });

    test( 'initialData seeds a new custom container', () async {
      final box = GetStorage(
        'initialDataContainer',
        null,
        <String, dynamic>{ 'seed': 'value' },
      );

      await box.initStorage;

      expect( box.read<String>( 'seed' ), 'value' );
    });
  });

  group( 'listeners', () {
    test( 'listen is called when container changes', () async {
      final box = GetStorage();

      var callCount = 0;

      final dispose = box.listen( () {
        callCount++;
      });

      await box.write( 'key', 'value' );

      expect( callCount, 1 );

      dispose();

      await box.write( 'key', 'new-value' );

      expect( callCount, 1 );
    });

    test( 'listenKey is called only for the matching key', () async {
      final box = GetStorage();

      dynamic observed;

      final dispose = box.listenKey( 'target', ( value ) {
        observed = value;
      });

      await box.write( 'other', 'ignored' );
      expect( observed, isNull );

      await box.write( 'target', 'captured' );
      expect( observed, 'captured' );

      dispose();

      await box.write( 'target', 'not-captured' );
      expect( observed, 'captured' );
    });

    test( 'changes exposes the most recent mutation', () async {
      final box = GetStorage();

      await box.write( 'latest', 42 );

      expect( box.changes, <String, dynamic>{ 'latest': 42 });

      await box.remove( 'latest' );

      expect( box.changes, <String, dynamic>{ 'latest': null });
    });
  });

  group( 'ReadWriteValue', () {
    test( 'extension val reads default value when missing', () {
      final value = 10.val( 'counter' );

      expect( value.val, 10 );
    });

    test( 'extension val writes and reads stored values', () {
      final value = 10.val( 'counter' );

      value.val = 25;

      expect( value.val, 25 );
      expect( GetStorage().read<int>( 'counter' ), 25 );
    });

    test( 'ReadWriteValue can target a custom container', () async {
      await GetStorage.init( 'delegateContainer' );

      final delegated = ReadWriteValue<int>(
        'count',
        0,
        () => GetStorage( 'delegateContainer' ),
      );

      delegated.val = 7;

      expect( delegated.val, 7 );
      expect( GetStorage( 'delegateContainer' ).read<int>( 'count' ), 7 );
    });
  });

  group( 'JSON-compatible value guidance', () {
    test( 'stores custom objects as maps', () async {
      final box = GetStorage();

      final user = _TestUser( id: 'u1', name: 'Ada' );

      await box.write( 'user', user.toJson() );

      final stored = box.read<Map<String, dynamic>>( 'user' );

      expect( stored, isNotNull );
      expect( _TestUser.fromJson( stored! ).name, 'Ada' );
    });

    test( 'stores custom objects as encoded strings', () async {
      final box = GetStorage();

      final user = _TestUser( id: 'u2', name: 'Grace' );

      await box.write( 'encodedUser', jsonEncode( user.toJson() ) );

      final stored = box.read<String>( 'encodedUser' );

      expect( stored, isNotNull );
      expect(
        _TestUser.fromJson( jsonDecode( stored! ) as Map<String, dynamic> ).name,
        'Grace',
      );
    });

    test( 'stores DateTime as ISO-8601 strings', () async {
      final box = GetStorage();
      final timestamp = DateTime.utc( 2026, 5, 31, 12, 0 );

      await box.write( 'timestamp', timestamp.toIso8601String() );

      final stored = box.read<String>( 'timestamp' );

      expect( DateTime.parse( stored! ), timestamp );
    });

    test( 'stores enums by name', () async {
      final box = GetStorage();

      await box.write( 'mode', _TestMode.enabled.name );

      final stored = box.read<String>( 'mode' );

      expect( _TestMode.values.byName( stored! ), _TestMode.enabled );
    });
  });

  group( 'IO persistence and recovery', () {
    test( 'save persists the current in-memory state', () async {
      final box = GetStorage();

      await box.write( 'persistent', 'value' );
      await box.save();

      final file = storageFile( testDirectory );

      expect( file.existsSync(), isTrue );
      expect( file.readAsStringSync(), contains( 'persistent' ) );
    });

    test( 'recovers from backup when primary file is corrupted', () async {
      final box = GetStorage();

      await box.write( 'recoverable', 'value' );
      await box.save();

      final file = storageFile( testDirectory );

      file.writeAsStringSync( 'not-json' );

      await GetStorage.init();

      expect( box.read<String>( 'recoverable' ), 'value' );
    });
  });
}

class _TestUser {
  const _TestUser({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
    };
  }

  factory _TestUser.fromJson( Map<String, dynamic> json ) {
    return _TestUser(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

enum _TestMode {
  enabled,
  disabled,
}
