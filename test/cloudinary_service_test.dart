import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skillforge_ai/core/services/cloudinary_service.dart';

void main() {
  group('CloudinaryService', () {
    test('returns secure_url from a successful upload', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'secure_url':
                'https://res.cloudinary.com/demo/image/upload/profile.jpg',
          }),
          200,
        );
      });
      final service = CloudinaryService(
        httpClient: client,
        cloudName: 'demo',
        uploadPreset: 'unsigned_profile',
        uploadFolder: 'skillforge/profile_images',
      );
      final image = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'avatar.jpg',
        mimeType: 'image/jpeg',
      );

      final result = await service.uploadProfileImage(image);

      expect(
        result,
        'https://res.cloudinary.com/demo/image/upload/profile.jpg',
      );
      expect(
        capturedRequest.url.toString(),
        'https://api.cloudinary.com/v1_1/demo/image/upload',
      );
      service.dispose();
    });

    test('rejects missing Cloudinary configuration', () async {
      final service = CloudinaryService(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        cloudName: '',
        uploadPreset: '',
      );

      await expectLater(
        service.uploadProfileImage(
          XFile.fromData(Uint8List.fromList([1]), name: 'avatar.jpg'),
        ),
        throwsA(
          isA<CloudinaryException>().having(
            (error) => error.message,
            'message',
            contains('not configured'),
          ),
        ),
      );
      service.dispose();
    });

    test('rejects files larger than 10 MB before upload', () async {
      final service = CloudinaryService(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        cloudName: 'demo',
        uploadPreset: 'unsigned_profile',
      );

      await expectLater(
        service.uploadProfileImage(
          XFile.fromData(
            Uint8List(CloudinaryService.maxFileSizeBytes + 1),
            name: 'avatar.png',
            mimeType: 'image/png',
          ),
        ),
        throwsA(
          isA<CloudinaryException>().having(
            (error) => error.message,
            'message',
            contains('too large'),
          ),
        ),
      );
      service.dispose();
    });

    test('rejects a success response without secure_url', () async {
      final service = CloudinaryService(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        cloudName: 'demo',
        uploadPreset: 'unsigned_profile',
      );

      await expectLater(
        service.uploadProfileImage(
          XFile.fromData(
            Uint8List.fromList([1]),
            name: 'avatar.webp',
            mimeType: 'image/webp',
          ),
        ),
        throwsA(
          isA<CloudinaryException>().having(
            (error) => error.message,
            'message',
            contains('invalid upload response'),
          ),
        ),
      );
      service.dispose();
    });
  });
}
