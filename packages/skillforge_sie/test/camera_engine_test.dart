import 'package:flutter_test/flutter_test.dart';
import 'package:skillforge_sie/skillforge_sie.dart';
import 'package:skillforge_sie/src/sie_camera/engine/sie_camera_stream_manager.dart';

class _GrantedPermission implements CameraPermissionPort {
  @override
  Future<SiePermissionStatus> check() async => SiePermissionStatus.granted;

  @override
  Future<SiePermissionStatus> request() async => SiePermissionStatus.granted;

  @override
  Future<bool> openSettings() async => false;
}

class _DeniedPermission implements CameraPermissionPort {
  @override
  Future<SiePermissionStatus> check() async => SiePermissionStatus.denied;

  @override
  Future<SiePermissionStatus> request() async => SiePermissionStatus.denied;

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  group('SieCameraSelectionStrategy', () {
    const strategy = SieCameraSelectionStrategy();
    const devices = [
      SieCameraDeviceInfo(
        id: 'back',
        name: 'Back',
        lensDirection: SieCameraLensDirection.back,
      ),
      SieCameraDeviceInfo(
        id: 'front',
        name: 'Front',
        lensDirection: SieCameraLensDirection.front,
      ),
    ];

    test('prefers front by default', () {
      final selected = strategy.select(
        devices: devices,
        config: const SieCameraConfig(),
      );
      expect(selected?.id, 'front');
    });

    test('honors preferredDeviceId', () {
      final selected = strategy.select(
        devices: devices,
        config: const SieCameraConfig(preferredDeviceId: 'back'),
      );
      expect(selected?.id, 'back');
    });

    test('returns null when empty', () {
      final selected = strategy.select(
        devices: const [],
        config: const SieCameraConfig(),
      );
      expect(selected, isNull);
    });
  });

  group('SieCameraEngine lifecycle', () {
    test('initialize → start → pause → resume → stop', () async {
      final adapter = FakeCameraPlatformAdapter(
        emitInterval: const Duration(milliseconds: 10),
      );
      final engine = SieCameraEngine(
        adapter: adapter,
        permissionPort: _GrantedPermission(),
        logger: const NopSieCameraLogger(),
      );

      await engine.initialize();
      expect(engine.currentStatus.state, SieCameraLifecycleState.ready);
      expect(engine.currentStatus.selected?.lensDirection,
          SieCameraLensDirection.front);

      final frames = <SieCameraFrame>[];
      final sub = engine.frames.listen(frames.add);

      await engine.start();
      expect(engine.currentStatus.state, SieCameraLifecycleState.streaming);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(frames, isNotEmpty);

      await engine.pause();
      expect(engine.currentStatus.state, SieCameraLifecycleState.paused);
      final countAfterPause = frames.length;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(frames.length, countAfterPause);

      await engine.resume();
      expect(engine.currentStatus.state, SieCameraLifecycleState.streaming);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(frames.length, greaterThan(countAfterPause));

      await engine.stop();
      expect(engine.currentStatus.state, SieCameraLifecycleState.idle);

      await sub.cancel();
      await engine.dispose();
      expect(engine.currentStatus.state, SieCameraLifecycleState.disposed);
    });

    test('permission denial surfaces typed failure', () async {
      final engine = SieCameraEngine(
        adapter: FakeCameraPlatformAdapter(),
        permissionPort: _DeniedPermission(),
        logger: const NopSieCameraLogger(),
      );
      expect(
        () => engine.initialize(),
        throwsA(isA<SiePermissionDeniedFailure>()),
      );
      await engine.dispose();
    });

    test('no cameras yields unavailable', () async {
      final adapter = FakeCameraPlatformAdapter(devices: const []);
      final engine = SieCameraEngine(
        adapter: adapter,
        permissionPort: _GrantedPermission(),
        logger: const NopSieCameraLogger(),
      );
      expect(
        () => engine.initialize(),
        throwsA(isA<SieCameraUnavailableFailure>()),
      );
      await engine.dispose();
    });

    test('unsupported streaming adapter fails gracefully', () async {
      final adapter = FakeCameraPlatformAdapter(
        supportsContinuousStreaming: false,
      );
      final engine = SieCameraEngine(
        adapter: adapter,
        permissionPort: _GrantedPermission(),
        logger: const NopSieCameraLogger(),
      );
      expect(
        () => engine.initialize(),
        throwsA(isA<SieCameraStreamingUnsupportedFailure>()),
      );
      await engine.dispose();
    });

    test('recover re-initializes and streams', () async {
      final adapter = FakeCameraPlatformAdapter(
        emitInterval: const Duration(milliseconds: 10),
      );
      final engine = SieCameraEngine(
        adapter: adapter,
        permissionPort: _GrantedPermission(),
        logger: const NopSieCameraLogger(),
      );
      await engine.initialize();
      await engine.start();
      await adapter.simulateDisconnect();
      await engine.recover();
      expect(engine.currentStatus.state, SieCameraLifecycleState.streaming);
      await engine.dispose();
    });

    test('dispose is idempotent', () async {
      final engine = SieCameraEngine(
        adapter: FakeCameraPlatformAdapter(),
        permissionPort: _GrantedPermission(),
        logger: const NopSieCameraLogger(),
      );
      await engine.dispose();
      await engine.dispose();
      expect(
        () => engine.start(),
        throwsA(isA<SieCameraLifecycleFailure>()),
      );
    });
  });

  group('SieCameraStreamManager back-pressure', () {
    test('publishes frames with increasing sequence', () async {
      final manager = SieCameraStreamManager(maxQueuedFrames: 1);
      final received = <int>[];
      final sub = manager.stream.listen((f) => received.add(f.sequence));
      for (var i = 0; i < 5; i++) {
        manager.publish(
          SieCameraFrame(
            timestamp: DateTime.now(),
            width: 1,
            height: 1,
            format: SieCameraImageFormat.unknown,
            planes: const [],
            rotationDegrees: 0,
            cameraId: 'x',
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(received, isNotEmpty);
      expect(received.first, 1);
      await sub.cancel();
      await manager.dispose();
    });
  });
}
