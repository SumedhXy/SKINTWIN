import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  CameraController? _controller;
  String? _error;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isTakingPicture) return;

    setState(() => _isTakingPicture = true);
    try {
      final image = await controller.takePicture();
      if (mounted) Navigator.pop(context, image);
    } catch (error) {
      if (mounted) {
        setState(() => _isTakingPicture = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture image: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('SkinTwin Camera'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              ),
            )
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _CaptureGuidePainter(),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      left: 18,
                      right: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.center_focus_strong, color: Colors.greenAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Place the skin finding inside the green frame',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              bottomSheet: controller != null && controller.value.isInitialized
                  ? SafeArea(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.78),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Clear photo checklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            SizedBox(height: 6),
                            Text('Keep the skin area inside the frame', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('Hold steady and use bright, even lighting', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('Avoid glare, shadows, blur, and filters', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  : null,
      floatingActionButton: controller != null && controller.value.isInitialized
          ? FloatingActionButton(
              onPressed: _takePicture,
              child: _isTakingPicture
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera_alt),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _CaptureGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final frameWidth = size.width * 0.76;
    final frameHeight = size.height * 0.46;
    final frame = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: frameWidth, height: frameHeight),
      const Radius.circular(24),
    );

    final shade = Paint()..color = Colors.black.withValues(alpha: 0.34);
    final outside = Path()..addRect(Offset.zero & size);
    final cutout = Path()..addRRect(frame);
    canvas.drawPath(Path.combine(PathOperation.difference, outside, cutout), shade);

    final border = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(frame, border);

    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const length = 24.0;
    final left = frame.left;
    final right = frame.right;
    final top = frame.top;
    final bottom = frame.bottom;
    for (final path in [
      Path()..moveTo(left, top + length)..lineTo(left, top)..lineTo(left + length, top),
      Path()..moveTo(right - length, top)..lineTo(right, top)..lineTo(right, top + length),
      Path()..moveTo(left, bottom - length)..lineTo(left, bottom)..lineTo(left + length, bottom),
      Path()..moveTo(right - length, bottom)..lineTo(right, bottom)..lineTo(right, bottom - length),
    ]) {
      canvas.drawPath(path, corner);
    }
  }

  @override
  bool shouldRepaint(covariant _CaptureGuidePainter oldDelegate) => false;
}
