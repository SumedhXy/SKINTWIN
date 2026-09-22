import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../network/dio_client.dart';
import '../theme.dart';

class AuthenticatedImage extends StatefulWidget {
  final String captureId;
  final BoxFit fit;
  final double? width;
  final double? height;
  final DioClient? dioClient;

  const AuthenticatedImage({
    super.key,
    required this.captureId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.dioClient,
  });

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  static final Map<String, Uint8List> _memoryCache = {};
  late final DioClient _dioClient;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dioClient = widget.dioClient ?? DioClient();
    if (_memoryCache.containsKey(widget.captureId)) {
      _imageBytes = _memoryCache[widget.captureId];
      _isLoading = false;
    } else {
      _loadImage();
    }
  }

  @override
  void didUpdateWidget(covariant AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.captureId != widget.captureId) {
      if (_memoryCache.containsKey(widget.captureId)) {
        setState(() {
          _imageBytes = _memoryCache[widget.captureId];
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        _loadImage();
      }
    }
  }

  Future<void> _loadImage() async {
    if (_memoryCache.containsKey(widget.captureId)) {
      if (mounted) {
        setState(() {
          _imageBytes = _memoryCache[widget.captureId];
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dioClient.dio.get(
        '/captures/${widget.captureId}/image',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data);
      _memoryCache[widget.captureId] = bytes;

      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load image';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryBlue,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_errorMessage != null || _imageBytes == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(_errorMessage ?? 'Unknown error', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      gaplessPlayback: true,
    );
  }
}
