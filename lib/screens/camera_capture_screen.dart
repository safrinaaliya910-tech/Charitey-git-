//camera_capture_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // NEW - to branch web vs mobile preview rendering
import 'package:camera/camera.dart';
import 'dart:async'; // NEW - for Timer

class CaptureResult {
  final Uint8List bytes;
  final String type; // 'image' | 'video'
  final String fileName;
  CaptureResult({required this.bytes, required this.type, required this.fileName});
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  CameraController? _controller;
  bool _isInitializing = true;
  String? _error;

  bool _isVideoMode = false;
  bool _isRecording = false;
  bool _isBusy = false;

  Timer? _recordingTimer;       // NEW
  int _recordingSeconds = 0;    // NEW

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = 'No camera found on this device.';
          _isInitializing = false;
        });
        return;
      }
      _selectedCameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _initController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _error = 'Camera access denied or unavailable: $e';
        _isInitializing = false;
      });
    }
  }

  // FIX: dispose the OLD controller fully before creating the new one.
  // Most devices only allow one open camera session at a time — creating
  // the new controller before releasing the old one is what caused the
  // front camera to come up blank/black.
  Future<void> _initController(CameraDescription description) async {
    setState(() => _isInitializing = true);

    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final newController = CameraController(
      description,
      ResolutionPreset.high,
      // FIX: audio track requests on web can trigger a second permission
      // prompt (mic) that silently fails/hangs on some browsers if the user
      // never responds to it, which was leaving the whole controller stuck
      // mid-initialization and the preview black. Only request audio on
      // native platforms where the video-recording flow actually needs it.
      enableAudio: !kIsWeb,
    );

    try {
      await newController.initialize();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Camera init failed: $e';
          _isInitializing = false;
        });
      }
      return;
    }

    if (!mounted) {
      await newController.dispose();
      return;
    }

    setState(() {
      _controller = newController;
      _isInitializing = false;
      _error = null;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isBusy || _isRecording) return;
    setState(() => _isBusy = true);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_selectedCameraIndex]);
    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      final XFile file = await _controller!.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      if (mounted) {
        Navigator.pop(
          context,
          CaptureResult(
            bytes: bytes,
            type: 'image',
            fileName: 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to capture: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

 Future<void> _toggleVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isBusy) return;

    if (!_isRecording) {
      setState(() => _isBusy = true);
      try {
        await _controller!.startVideoRecording();
        setState(() {
          _isRecording = true;
          _isBusy = false;
          _recordingSeconds = 0; // reset counter
        });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordingSeconds++);
        });
      } catch (e) {
        setState(() => _isBusy = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start recording: $e')));
        }
      }
    } else {
      setState(() => _isBusy = true);
      try {
        _recordingTimer?.cancel(); // stop the ticking clock
        final XFile file = await _controller!.stopVideoRecording();
        final Uint8List bytes = await file.readAsBytes();
        setState(() {
          _isRecording = false;
          _isBusy = false;
          _recordingSeconds = 0;
        });
        if (mounted) {
          Navigator.pop(
            context,
            CaptureResult(
              bytes: bytes,
              type: 'video',
              fileName: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
            ),
          );
        }
      } catch (e) {
        _recordingTimer?.cancel();
        setState(() {
          _isRecording = false;
          _isBusy = false;
          _recordingSeconds = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save recording: $e')));
        }
      }
    }
  }

  void _onShutterTap() => _isVideoMode ? _toggleVideoRecording() : _takePhoto();

  // NEW: formats seconds as mm:ss
  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleMode() {
    if (_isRecording || _isBusy) return;
    setState(() => _isVideoMode = !_isVideoMode);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recordingTimer?.cancel(); // NEW
    super.dispose();
  }

  // FIX: CameraPreview on Flutter Web is backed by a real HTML <video>
  // element (a platform view), not a Skia texture like on mobile. Platform
  // views on web do NOT reliably render inside nested OverflowBox/FittedBox/
  // SizedBox transform tricks — the <video> element ends up sized to 0,
  // hidden, or stuck showing a stale frame, which is exactly the black
  // preview you were seeing. So on web we skip the crop-to-fill trick
  // entirely and just show the preview at its native aspect ratio, centered.
  // On mobile (native texture-based preview) the crop-to-fill still works
  // fine and looks better full-bleed, so that path is unchanged.
  Widget _buildFullScreenPreview() {
    final controller = _controller!;

    if (kIsWeb) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final previewW = isPortrait ? previewSize.height : previewSize.width;
    final previewH = isPortrait ? previewSize.width : previewSize.height;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewW,
            height: previewH,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                ),
              )
            : _isInitializing || _controller == null || !_controller!.value.isInitialized
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildFullScreenPreview(),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                            if (_isRecording)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDuration(_recordingSeconds), // NEW: live timer instead of static "REC"
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const SizedBox(width: 28),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildModeButton(),
                            _buildShutterButton(),
                            _buildFlipButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildModeButton() {
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 30,
            icon: Icon(
              _isVideoMode ? Icons.videocam : Icons.videocam_outlined,
              color: _isVideoMode ? Colors.redAccent : Colors.white,
            ),
            onPressed: _toggleMode,
          ),
          Text(
            'Video',
            style: TextStyle(
              color: _isVideoMode ? Colors.redAccent : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _onShutterTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isRecording ? 30 : 60,
            height: _isRecording ? 30 : 60,
            decoration: BoxDecoration(
              color: _isVideoMode ? Colors.redAccent : Colors.white,
              borderRadius: BorderRadius.circular(_isRecording ? 8 : 30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlipButton() {
    return SizedBox(
      width: 70,
      child: IconButton(
        iconSize: 32,
        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
        onPressed: _flipCamera,
      ),
    );
  }
}