/// Legacy compatibility entrypoint.
///
/// This file previously contained a dart:html implementation. It now forwards
/// to the modern dart:js_interop web backend so projects importing this file
/// directly do not receive deprecated dart:html warnings.
export 'web.dart';
