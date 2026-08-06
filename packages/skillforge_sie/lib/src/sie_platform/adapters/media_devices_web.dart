import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Returns whether `navigator.mediaDevices` exists.
bool hasMediaDevices() {
  try {
    if (!globalContext.has('navigator')) return false;
    final navigatorAny = globalContext.getProperty('navigator'.toJS);
    if (navigatorAny == null || !navigatorAny.isA<JSObject>()) return false;
    // ignore: avoid_as — JS interop narrowing after isA check
    final navigator = navigatorAny as JSObject;
    return navigator.has('mediaDevices');
  } catch (_) {
    return false;
  }
}
