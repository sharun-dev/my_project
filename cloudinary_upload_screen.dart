import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'models/cloudinary_upload_result.dart';
import 'services/cloudinary_uploader.dart';

class CloudinaryUploadScreen extends StatefulWidget {
  const CloudinaryUploadScreen({super.key});

  @override
  State<CloudinaryUploadScreen> createState() => _CloudinaryUploadScreenState();
}

class _CloudinaryUploadScreenState extends State<CloudinaryUploadScreen> {
  final CloudinaryUploader _uploader = CloudinaryUploader();
  final ImagePicker _picker = ImagePicker();

  File? _selectedFile;
  String? _selectedType; // ``image`` or ``video``

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  CloudinaryUploadResult? _uploadedResult;
  VideoPlayerController? _previewVideoController;
  VideoPlayerController? _networkVideoController;

  @override
  void dispose() {
    _previewVideoController?.dispose();
    _networkVideoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia({required bool image}) async {
    try {
      _errorMessage = null;
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (!image) {
        final XFile? videoFile = await _picker.pickVideo(source: ImageSource.gallery);
        if (videoFile == null) return;
        _selectedFile = File(videoFile.path);
        _selectedType = 'video';
      } else {
        if (file == null) return;
        _selectedFile = File(file.path);
        _selectedType = 'image';
      }

      _previewVideoController?.dispose();
      _networkVideoController?.dispose();
      _previewVideoController = null;
      _networkVideoController = null;
      _uploadedResult = null;

      if (_selectedType == 'video' && _selectedFile != null) {
        _previewVideoController = VideoPlayerController.file(_selectedFile!);
        await _previewVideoController!.initialize();
        _previewVideoController!.setLooping(true);
        setState(() {});
      } else {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick file: $e';
      });
    }
  }

  Future<void> _uploadSelectedMedia() async {
    if (_selectedFile == null || _selectedType == null) {
      setState(() {
        _errorMessage = 'Please select a file first';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      CloudinaryUploadResult result;
      if (_selectedType == 'image') {
        result = await _uploader.uploadImage(
          _selectedFile!,
          (progress) => setState(() {
            _uploadProgress = progress;
          }),
        );
      } else {
        result = await _uploader.uploadVideo(
          _selectedFile!,
          (progress) => setState(() {
            _uploadProgress = progress;
          }),
        );
      }

      setState(() {
        _uploadedResult = result;
        _isUploading = false;
        _uploadProgress = 0;
      });

      if (result.resourceType == 'video') {
        _networkVideoController?.dispose();
        _networkVideoController = VideoPlayerController.network(result.url);
        await _networkVideoController!.initialize();
        _networkVideoController!.setLooping(true);
        await _networkVideoController!.play();
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Widget _buildSelectedPreview() {
    if (_selectedFile == null || _selectedType == null) {
      return const Text('No local media selected');
    }

    if (_selectedType == 'image') {
      return Image.file(
        _selectedFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
      );
    }

    if (_previewVideoController != null && _previewVideoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _previewVideoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_previewVideoController!),
            VideoProgressIndicator(_previewVideoController!, allowScrubbing: true),
          ],
        ),
      );
    }

    return const Text('Loading selected video...');
  }

  Widget _buildUploadedPreview() {
    if (_uploadedResult == null) {
      return const SizedBox.shrink();
    }

    if (_uploadedResult!.resourceType == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Uploaded Image:', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Image.network(
            _uploadedResult!.url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
          ),
        ],
      );
    }

    if (_networkVideoController != null && _networkVideoController!.value.isInitialized) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Uploaded Video:', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: _networkVideoController!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                VideoPlayer(_networkVideoController!),
                VideoProgressIndicator(_networkVideoController!, allowScrubbing: true),
              ],
            ),
          ),
        ],
      );
    }

    return const Text('Initializing uploaded video...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloudinary Image/Video Upload'),
        backgroundColor: const Color(0xFF1E1B2E),
      ),
      backgroundColor: const Color(0xFF0F0F1B),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickMedia(image: true),
                    icon: const Icon(Icons.photo),
                    label: const Text('Pick Image'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickMedia(image: false),
                    icon: const Icon(Icons.video_library),
                    label: const Text('Pick Video'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Local preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(height: 200, child: _buildSelectedPreview()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadSelectedMedia,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_isUploading ? 'Uploading...' : 'Upload to Cloudinary'),
            ),
            const SizedBox(height: 12),
            if (_isUploading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upload progress', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('${(_uploadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white)),
                ],
              ),
            const SizedBox(height: 24),
            _buildUploadedPreview(),
            if (_uploadedResult != null) ...[
              const SizedBox(height: 12),
              Text('URL: ${_uploadedResult!.url}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
            if (_errorMessage != null && _selectedFile != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _uploadSelectedMedia,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Upload'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
