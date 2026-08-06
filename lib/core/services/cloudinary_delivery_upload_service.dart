import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/cloudinary_config.dart';

class CloudinaryDeliveryUploadException implements Exception {
  const CloudinaryDeliveryUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudinaryDeliveryUploadService {
  CloudinaryDeliveryUploadService({
    ImagePicker? imagePicker,
    http.Client? httpClient,
    String cloudName = CloudinaryConfig.cloudName,
    String uploadPreset = CloudinaryConfig.uploadPreset,
    String deliveryFolder = CloudinaryConfig.deliveryFolder,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _httpClient = httpClient ?? http.Client(),
       _cloudName = cloudName,
       _uploadPreset = uploadPreset,
       _deliveryFolder = deliveryFolder;

  static const maxFiles = 10;
  static const maxFileSizeBytes = 25 * 1024 * 1024;
  static const _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'doc',
    'docx',
    'txt',
    'zip',
  };

  final ImagePicker _imagePicker;
  final http.Client _httpClient;
  final String _cloudName;
  final String _uploadPreset;
  final String _deliveryFolder;

  Future<List<XFile>> pickDeliveryFiles() async {
    final files = await _imagePicker.pickMultipleMedia();
    return files.take(maxFiles).toList();
  }

  Future<List<Map<String, dynamic>>> uploadDeliveryFiles(
    List<XFile> files,
  ) async {
    if (_cloudName.trim().isEmpty || _uploadPreset.trim().isEmpty) {
      throw const CloudinaryDeliveryUploadException(
        'Upload service is not configured yet.',
      );
    }
    if (files.length > maxFiles) {
      throw const CloudinaryDeliveryUploadException(
        'Attach up to 10 delivery files.',
      );
    }

    final attachments = <Map<String, dynamic>>[];
    for (final file in files) {
      attachments.add(await _uploadOne(file));
    }
    return attachments;
  }

  Future<Map<String, dynamic>> _uploadOne(XFile file) async {
    final extension = _fileExtension(file.name);
    if (!_allowedExtensions.contains(extension)) {
      throw CloudinaryDeliveryUploadException(
        'Unsupported file type: ${file.name}.',
      );
    }
    final fileSize = await file.length();
    if (fileSize <= 0) {
      throw const CloudinaryDeliveryUploadException('Selected file is empty.');
    }
    if (fileSize > maxFileSizeBytes) {
      throw CloudinaryDeliveryUploadException(
        '${file.name} is larger than 25 MB.',
      );
    }

    final endpoint = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$_cloudName/auto/upload',
    );
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = _deliveryFolder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          await file.readAsBytes(),
          filename: file.name.trim().isEmpty
              ? 'delivery.$extension'
              : file.name,
        ),
      );

    try {
      final streamed = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CloudinaryDeliveryUploadException(
          _cloudinaryError(body) ?? 'Delivery upload failed.',
        );
      }
      final secureUrl = body['secure_url']?.toString() ?? '';
      if (secureUrl.trim().isEmpty) {
        throw const CloudinaryDeliveryUploadException(
          'Cloudinary returned an invalid upload response.',
        );
      }
      final now = DateTime.now();
      return {
        'url': secureUrl,
        'secureUrl': secureUrl,
        'publicId': body['public_id']?.toString() ?? '',
        'fileName': file.name,
        'fileType': extension,
        'mimeType': file.mimeType ?? '',
        'fileSize': fileSize,
        'resourceType':
            body['resource_type']?.toString() ?? _resourceType(extension),
        'uploadedAt': Timestamp.fromDate(now),
      };
    } on CloudinaryDeliveryUploadException {
      rethrow;
    } on TimeoutException {
      throw const CloudinaryDeliveryUploadException(
        'The upload timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const CloudinaryDeliveryUploadException(
        'Unable to reach Cloudinary. Check your internet connection.',
      );
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected Cloudinary JSON object.');
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

  String _resourceType(String extension) {
    return switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' => 'image',
      _ => 'raw',
    };
  }

  void dispose() {
    _httpClient.close();
  }
}
