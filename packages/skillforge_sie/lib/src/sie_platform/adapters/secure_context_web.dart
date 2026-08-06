import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web secure-context check (`window.isSecureContext`).
bool isSecureContext() {
  try {
    if (!globalContext.has('isSecureContext')) return false;
    final value = globalContext.getProperty('isSecureContext'.toJS);
    return value != null && value.isA<JSBoolean>() && value == true.toJS;
  } catch (_) {
    return false;
  }
}
