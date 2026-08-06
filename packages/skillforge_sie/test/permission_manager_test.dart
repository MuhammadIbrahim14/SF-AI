import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';

class _FakePermissionPort implements CameraPermissionPort {
  _FakePermissionPort(this._status);

  SiePermissionStatus _status;
  int requestCount = 0;
  int openSettingsCount = 0;

  set status(SiePermissionStatus value) => _status = value;

  @override
  Future<SiePermissionStatus> check() async => _status;

  @override
  Future<SiePermissionStatus> request() async {
    requestCount += 1;
    if (_status == SiePermissionStatus.permanentlyDenied) {
      return _status;
    }
    _status = SiePermissionStatus.granted;
    return _status;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount += 1;
    return true;
  }
}

void main() {
  group('SiePermissionManager', () {
    test('refresh maps status into guidance snapshot', () async {
      final port = _FakePermissionPort(SiePermissionStatus.denied);
      final manager = SiePermissionManager(permissionPort: port);
      final snap = await manager.refresh();
      expect(snap.status, SiePermissionStatus.denied);
      expect(snap.canRequest, isTrue);
      expect(snap.guidanceBody, isNotNull);
    });

    test('request promotes denied to granted via port', () async {
      final port = _FakePermissionPort(SiePermissionStatus.denied);
      final manager = SiePermissionManager(permissionPort: port);
      final snap = await manager.requestCameraPermission();
      expect(snap.status, SiePermissionStatus.granted);
      expect(port.requestCount, 1);
    });

    test('permanent denial does not call request', () async {
      final port = _FakePermissionPort(SiePermissionStatus.permanentlyDenied);
      final manager = SiePermissionManager(permissionPort: port);
      await manager.refresh();
      final snap = await manager.requestCameraPermission();
      expect(snap.needsSettings, isTrue);
      expect(port.requestCount, 0);
    });

    test('ensureGranted returns failure when denied', () async {
      final port = _FakePermissionPort(SiePermissionStatus.denied);
      // Force request to keep denied
      port.status = SiePermissionStatus.denied;
      final manager = SiePermissionManager(permissionPort: port);
      // Override request behavior by setting permanently denied after check
      final failure = await manager.ensureGranted(requestIfNeeded: false);
      expect(failure, isA<SiePermissionDeniedFailure>());
    });

    test('ensureGranted returns null when granted', () async {
      final port = _FakePermissionPort(SiePermissionStatus.granted);
      final manager = SiePermissionManager(permissionPort: port);
      final failure = await manager.ensureGranted();
      expect(failure, isNull);
    });

    test('openPermissionSettings delegates to port', () async {
      final port = _FakePermissionPort(SiePermissionStatus.permanentlyDenied);
      final manager = SiePermissionManager(permissionPort: port);
      final opened = await manager.openPermissionSettings();
      expect(opened, isTrue);
      expect(port.openSettingsCount, 1);
    });
  });

  group('SiePermissionSnapshot', () {
    test('fromStatus covers permanent denial guidance', () {
      final snap = SiePermissionSnapshot.fromStatus(
        SiePermissionStatus.permanentlyDenied,
      );
      expect(snap.needsSettings, isTrue);
      expect(snap.canRequest, isFalse);
      expect(snap.guidanceTitle, contains('settings'));
    });
  });
}
