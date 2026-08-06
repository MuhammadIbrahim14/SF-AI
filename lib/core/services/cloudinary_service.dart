import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/cloudinary_config.dart';

class CloudinaryException implements Exception {
  const CloudinaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudinaryService {
  CloudinaryService({
    ImagePicker? imagePicker,
    http.Client? httpClient,
    String cloudName = CloudinaryConfig.cloudName,
    String uploadPreset = CloudinaryConfig.uploadPreset,
    String uploadFolder = CloudinaryConfig.uploadFolder,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _httpClient = httpClient ?? http.Client(),
       _cloudName = cloudName,
       _uploadPreset = uploadPreset,
       _uploadFolder = uploadFolder;

  static const int maxFileSizeBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final ImagePicker _imagePicker;
  final http.Client _httpClient;
  final String _cloudName;
  final String _uploadPreset;
  final String _uploadFolder;

  Future<XFile?> pickImageFromGallery() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1400,
    );
  }

  Future<String> uploadProfileImage(XFile image) async {
    if (_cloudName.trim().isEmpty || _uploadPreset.trim().isEmpty) {
      throw const CloudinaryException(
        'Cloudinary is not configured. Add CLOUDINARY_CLOUD_NAME and '
        'CLOUDINARY_UPLOAD_PRESET to your build environment.',
      );
    }

    final fileExtension = _fileExtension(image.name);
    final extension = fileExtension.isNotEmpty
        ? fileExtension
        : _extensionForMimeType(image.mimeType);
    if (!_allowedExtensions.contains(extension)) {
      throw const CloudinaryException(
        'Please select a JPG, PNG, or WebP image.',
      );
    }

    final fileSize = await image.length();
    if (fileSize == 0) {
      throw const CloudinaryException('The selected image is empty.');
    }
    if (fileSize > maxFileSizeBytes) {
      throw const CloudinaryException(
        'The selected image is too large. Maximum size is 10 MB.',
      );
    }
    final bytes = await image.readAsBytes();

    final endpoint = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = _uploadFolder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: image.name.trim().isEmpty
              ? 'profile.$extension'
              : image.name,
        ),
      );

    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      final body = _decodeBody(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final cloudinaryMessage = _cloudinaryError(body);
        throw CloudinaryException(
          cloudinaryMessage ?? 'Image upload failed. Please try again.',
        );
      }

      final secureUrl = body['secure_url'];
      if (secureUrl is! String || secureUrl.trim().isEmpty) {
        throw const CloudinaryException(
          'Cloudinary returned an invalid upload response.',
        );
      }
      return secureUrl;
    } on CloudinaryException {
      rethrow;
    } on TimeoutException {
      throw const CloudinaryException(
        'The upload timed out. Check your connection and try again.',
      );
    } on FormatException {
      throw const CloudinaryException(
        'Cloudinary returned an invalid upload response.',
      );
    } on http.ClientException {
      throw const CloudinaryException(
        'Unable to reach Cloudinary. Check your internet connection and try again.',
      );
    } catch (error) {
      throw CloudinaryException('Image upload failed: $error');
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  String? _cloudinaryError(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    return null;
  }

  String _fileExtension(String fileName) {
    final separator = fileName.lastIndexOf('.');
    if (separator < 0 || separator == fileName.length - 1) return '';
    return fileName.substring(separator + 1).toLowerCase();
  }

  String _extensionForMimeType(String? mimeType) {
    return switch (mimeType?.toLowerCase()) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => '',
    };
  }

  void dispose() {
    _httpClient.close();
  }
}
