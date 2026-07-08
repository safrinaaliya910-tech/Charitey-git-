import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class MediaPreviewScreen extends StatefulWidget {
  final Uint8List bytes;
  final String type; // 'image' | 'video' | 'document'
  final String fileName;

  const MediaPreviewScreen({
    super.key,
    required this.bytes,
    required this.type,
    required this.fileName,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') _setupVideo();
  }

  Future<void> _setupVideo() async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await tempFile.writeAsBytes(widget.bytes);
    _videoController = VideoPlayerController.file(tempFile)
      ..initialize().then((_) {
        if (mounted) setState(() => _videoReady = true);
        _videoController!.setLooping(true);
        _videoController!.play();
      });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.pop(context); // returns null -> caller treats as cancelled
  void _send() => Navigator.pop(context, _captionController.text.trim()); // returns caption ("" if blank)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top-left cancel (X) — matches WhatsApp reference
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  onPressed: _cancel,
                ),
              ],
            ),

            // Media preview
            Expanded(
              child: Center(
                child: widget.type == 'image'
                    ? InteractiveViewer(child: Image.memory(widget.bytes, fit: BoxFit.contain))
                    : widget.type == 'video'
                        ? (_videoReady
                            ? AspectRatio(
                                aspectRatio: _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              )
                            : const CircularProgressIndicator(color: Colors.white))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insert_drive_file, color: Colors.white, size: 90),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  widget.fileName,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
              ),
            ),

            // Bottom: caption input + send — matches WhatsApp reference
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF7D444C),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}