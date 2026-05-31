///  Library: getxtra_storage
///
///  File:    lib/src/value.dart
///
///  Desc:    This file provides a definition for the ValueStorage class, which
///           provides value storage services into the package.
///

/// Package Imports for the module
import 'storage_impl.dart';

typedef StorageFactory = GetStorage Function();

class ReadWriteValue<T> {
  final String key;
  final T defaultValue;
  final StorageFactory? getBox;
  // final EncodeObject encoder;

  ReadWriteValue(
    this.key,
    this.defaultValue, [
    this.getBox,
    //  this.encoder,
  ]);

  GetStorage _getRealBox() => getBox?.call() ?? GetStorage();

  T get val => _getRealBox().read( key ) ?? defaultValue;
  set val( T newVal ) => _getRealBox().write( key, newVal );
}

extension Data<T> on T {
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
