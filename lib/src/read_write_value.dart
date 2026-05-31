///  Library: getxtra_storage
///
///  File:    lib/src/read_write_value.dart
///
///  Desc:    This file provides the ReadWriteValue<T> abstraction and related
///           extension helpers used to expose storage-backed values as simple
///           Dart properties.
///
///           ReadWriteValue acts as a lightweight bridge between application
///           code and a GetStorage container, allowing callers to interact
///           with persisted values through a familiar getter/setter pattern
///           instead of repeatedly calling read() and write().
///
///           This API is one of the primary convenience features inherited from
///           the original get_storage package and enables SharedPreferences-like
///           usage patterns while retaining GetStorage's in-memory performance
///           characteristics.
///
///           The accompanying Data<T> extension allows any Dart value to be
///           transformed into a storage-backed property definition using the
///           concise `.val()` syntax.
///
///           Example:
///
///             final username = ''.val( 'username' );
///
///             username.val = 'john.doe';
///             print( username.val );
///
///           This design remains fully compatible with existing get_storage
///           applications and serves as an important migration path for
///           developers adopting getxtra_storage.
///

/// Package Imports for the module
import 'storage_impl.dart';

/// Signature used to lazily provide a storage container.
///
/// This allows ReadWriteValue instances to target alternate containers
/// instead of always using the default GetStorage instance.
typedef StorageFactory = GetStorage Function();

/// Represents a storage-backed property.
///
/// A ReadWriteValue behaves similarly to a normal Dart field while
/// transparently reading from and writing to a GetStorage container.
///
/// The value is persisted under [key], and [defaultValue] is returned
/// whenever no value currently exists within the container.
///
/// Example:
///
/// ```dart
/// final username = ReadWriteValue<String>(
///   'username',
///   '',
/// );
///
/// username.val = 'john.doe';
///
/// print( username.val );
/// ```
class ReadWriteValue<T> {

  /// Storage key used to persist and retrieve the value.
  final String key;

  /// Value returned when no stored value exists for [key].
  final T defaultValue;

  /// Optional storage container provider.
  ///
  /// If omitted, the default GetStorage container is used.
  final StorageFactory? getBox;

  // final EncodeObject encoder;

  /// Creates a new storage-backed property definition.
  ///
  /// [key] identifies the storage entry.
  ///
  /// [defaultValue] is returned whenever the entry does not yet exist.
  ///
  /// [getBox] may be supplied to target a specific storage container.
  ReadWriteValue(
    this.key,
    this.defaultValue, [
    this.getBox,
    //  this.encoder,
  ]);

  /// Resolves the storage container used for all read and write operations.
  ///
  /// If a custom container factory has been supplied, it will be used.
  /// Otherwise the default GetStorage container is returned.
  GetStorage _getRealBox() => getBox?.call() ?? GetStorage();

  /// Reads the current value from storage.
  ///
  /// If no value exists for [key], [defaultValue] is returned instead.
  T get val => _getRealBox().read( key ) ?? defaultValue;

  /// Writes a new value to storage.
  ///
  /// The value is immediately available in memory and will be persisted
  /// according to the underlying GetStorage implementation.
  set val( T newVal ) => _getRealBox().write( key, newVal );
}

/// Extension providing the concise `.val()` syntax.
///
/// This allows any Dart value to become the default value for a
/// storage-backed property definition.
///
/// Example:
///
/// ```dart
/// final username = ''.val( 'username' );
///
/// username.val = 'john.doe';
///
/// print( username.val );
/// ```
extension Data<T> on T {

  /// Creates a storage-backed property definition.
  ///
  /// [valueKey] identifies the storage entry.
  ///
  /// [getBox] optionally selects a specific storage container.
  ///
  /// [defVal] overrides the extension receiver as the default value.
  ReadWriteValue<T> val(
    String valueKey,
    {
      StorageFactory? getBox,
      T? defVal,
    }
  ) {
    return ReadWriteValue( valueKey, defVal ?? this, getBox );
  }
}
