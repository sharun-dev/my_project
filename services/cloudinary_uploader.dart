import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../models/cloudinary_upload_result.dart';

class CloudinaryUploadException implements Exception {
  final String message;
  CloudinaryUploadException(this.message);

  @override
  String toString() => 'CloudinaryUploadException: $message';
}

class CloudinaryUploader {
  // Cloudinary configuration (user requirement)
  static const String cloudName = 'dkz5wmhge';
  static const String uploadPreset = 'test-preset';
  static const String apiKey = '459514343398154';  // Replace with your Cloudinary API key
  static const String apiSecret = 't2sS1B98HxdKt_92ftu8GPYwwH0';  // Replace with your Cloudinary API secret

  final Dio _dio;

  CloudinaryUploader({Dio? dio}) : _dio = dio ?? Dio();

  /// Uploads an image file to Cloudinary and returns a [CloudinaryUploadResult].
  Future<CloudinaryUploadResult> uploadImage(
    File file,
    void Function(double progress)? onSendProgress,
  ) async {
    return uploadMedia(file, 'image', onSendProgress, uploadPreset: uploadPreset);
  }

  /// Uploads a video file to Cloudinary and returns a [CloudinaryUploadResult].
  Future<CloudinaryUploadResult> uploadVideo(
    File file,
    void Function(double progress)? onSendProgress,
  ) async {
    return uploadMedia(file, 'video', onSendProgress, uploadPreset: null);
  }

  /// Uploads a raw file (pdf/doc/xls/text) to Cloudinary.
  Future<CloudinaryUploadResult> uploadRaw(
    File file,
    void Function(double progress)? onSendProgress,
  ) async {
    return uploadMedia(file, 'raw', onSendProgress, uploadPreset: null);
  }

  /// Uploads an image/video/raw to Cloudinary.
  Future<CloudinaryUploadResult> uploadMedia(
    File file,
    String resourceType,
    void Function(double progress)? onSendProgress, {
    String? uploadPreset,
  }) async {
    if (!file.existsSync()) {
      throw CloudinaryUploadException('File does not exist');
    }

    final url = 'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload';

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final params = <String, String>{
      'timestamp': timestamp,
      if (uploadPreset != null) 'upload_preset': uploadPreset,
    };
    final sortedKeys = params.keys.toList()..sort();
    final paramString = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    final signature = sha1.convert(utf8.encode(paramString + apiSecret)).toString();

    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
      if (uploadPreset != null) 'upload_preset': uploadPreset,
      'api_key': apiKey,
      'timestamp': timestamp,
      'signature': signature,
      'resource_type': resourceType,
    });

    try {
      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
        onSendProgress: (count, total) {
          if (total > 0 && onSendProgress != null) {
            onSendProgress(count / total);
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        final String secureUrl = (responseData['secure_url'] as String?)?.trim() ?? '';
        if (secureUrl.isEmpty) {
          throw CloudinaryUploadException('Cloudinary response missing secure_url');
        }

        return CloudinaryUploadResult(url: secureUrl, resourceType: resourceType);
      } else {
        throw CloudinaryUploadException(
          'Upload failed with status ${response.statusCode}',
        );
      }
    } on DioError catch (e) {
      String errorMessage = 'Unknown Cloudinary error';
      if (e.response != null) {
        errorMessage = 'Status: ${e.response?.statusCode}; ${e.response?.data}';
      } else {
        errorMessage = e.message ?? 'Unknown Dio error';
      }
      throw CloudinaryUploadException(errorMessage);
    } catch (e) {
      throw CloudinaryUploadException(e.toString());
    }
  }
}
