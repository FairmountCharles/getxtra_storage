/// ---------------------------------------------------------------------------
/// Library: getxtra_storage
///
/// File:    lib/src/value.dart
///
/// Desc:
///   Defines the ValueStorage<T> class, a lightweight reactive wrapper used
///   internally by getxtra_storage to track storage state and broadcast change
///   notifications.
///
///   ValueStorage acts as the observable backing store for container data,
///   allowing GetStorage instances to notify listeners whenever values are
///   added, updated, removed, or cleared.
///
///   Unlike the original get_storage implementation, which directly inherited
///   from GetX's Value<T>, this implementation composes a getxtra Value<T>
///   instance internally. This preserves compatibility with the public
///   GetStorage API while reducing coupling to framework internals.
///
///   The class also maintains a lightweight "changes" map containing the most
///   recent key/value mutation. This enables listenKey() and related APIs to
///   efficiently determine which storage entry changed without requiring a
///   full comparison of the storage container.
///
///   This class is considered an internal infrastructure component and is not
///   typically interacted with directly by package consumers.
///
/// Original Concept:
///   get_storage (Jonatas Borges / GetX)
///
/// Modernized For:
///   getxtra_storage
/// ---------------------------------------------------------------------------

/// Flutter imports.
import 'package:flutter/widgets.dart' show VoidCallback;

/// GetXtra imports.
import 'package:getxtra/get.dart' show Value;

/// Internal reactive value wrapper used by getxtra_storage.
class ValueStorage<T> {
  /// Creates a new reactive storage wrapper initialized with [value].
  ///
  /// The supplied value becomes the initial observable state.
  ValueStorage( T value ) : this._value = Value( value );

  /// Underlying reactive value implementation provided by getxtra.
  final Value _value;

  /// Contains the most recent storage mutation.
  ///
  /// The map is expected to contain a single key/value pair representing
  /// the last change that occurred within the storage container.
  ///
  /// Example:
  /// ```dart
  /// {
  ///   'username': 'john.doe'
  /// }
  /// ```
  ///
  /// When a key is removed, the value will typically be null.
  Map<String, dynamic> changes = <String, dynamic>{};

  /// Records a storage mutation and notifies all listeners.
  ///
  /// The [key] identifies the entry that changed and [value] represents
  /// its new value. For removals, [value] is generally null.
  ///
  /// After updating the changes map, a refresh notification is issued so
  /// any registered listeners can react immediately.
  void changeValue( String key, dynamic value ) {
    changes = { key: value };

    // Trigger listener notifications.
    //
    // Value.refresh() is currently protected within getxtra, so this call
    // intentionally bypasses the analyzer warning to preserve behavior
    // compatible with the original get_storage implementation.
    // ignore: invalid_use_of_protected_member
    _value.refresh();
  }

  /// Returns the current stored value.
  T get value => _value.value;

  /// Replaces the current stored value.
  ///
  /// Listener notifications are handled by the underlying Value<T>
  /// implementation when appropriate.
  set value( T value ) {
    _value.value = value;
  }

  /// Registers a listener that will be invoked whenever storage changes.
  ///
  /// Returns a disposal callback which can be invoked to remove the listener.
  ///
  /// Example:
  /// ```dart
  /// final dispose = storage.addListener( () {
  ///   print( 'Storage changed' );
  /// });
  ///
  /// dispose();
  /// ```
  VoidCallback addListener( VoidCallback callback ) {
    _value.addListener( callback );

    return () => _value.removeListener( callback );
  }
}
