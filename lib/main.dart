import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

void main() => runApp(const MaterialApp(
    debugShowCheckedModeBanner: false, home: VideoCreatorApp()));

class VideoCreatorApp extends StatefulWidget {
  const VideoCreatorApp({super.key});

  @override
  _VideoCreatorAppState createState() => _VideoCreatorAppState();
}

class _VideoCreatorAppState extends State<VideoCreatorApp> {
  List<XFile> _selectedImages = [];
  bool _isProcessing = false;

  Future<void> _pickImages() async {
    final images = await ImagePicker().pickMultiImage(limit: 5);
    if (images.length >= 3) {
      setState(() => _selectedImages = images.take(5).toList());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select between 3 to 5 images.')),
      );
    }
  }

  Future<void> _exportVideo() async {
    if (_selectedImages.length < 3) return;

    setState(() => _isProcessing = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final videoPath = '${tempDir.path}/final_output.mp4';

      await _createVideo(videoPath);

      await SaverGallery.saveFile(
        filePath: videoPath,
        skipIfExists: true,
        fileName: 'final_output.mp4',
        androidRelativePath: "Movies",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video saved to gallery!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _createVideo(String outputPath) async {
    final musicFile = await _getMusicFile();
    final command = _buildFFmpegCommand(outputPath, musicFile.path);

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (returnCode!.isValueError()) {
      throw Exception(
          'FFmpeg processing failed: ${await session.getFailStackTrace()}');
    }
  }

  String _buildFFmpegCommand(String outputPath, String musicPath) {
    final imageInputs =
        _selectedImages.map((img) => '-loop 1 -t 3 -i "${img.path}"').join(' ');

    return [
      '-y',
      imageInputs,
      '-i "$musicPath"',
      '-filter_complex "${_buildFilterComplex()}"',
      '-map "[v]"',
      '-map "${_selectedImages.length}:a"',
      '-c:v libx264',
      '-c:a aac',
      '-shortest',
      '-pix_fmt yuv420p',
      '"$outputPath"'
    ].join(' ');
  }

  String _buildFilterComplex() {
    final int count = _selectedImages.length;
    final double transitionDuration = 1.0;
    final double firstOffset = 3.0 - transitionDuration; // = 2.0 seconds

    final StringBuffer buffer = StringBuffer();
    String previous = '0:v';
    for (int i = 1; i < count; i++) {
      double offset = firstOffset + (i - 1) * (3.0 - transitionDuration);
      String currentOutput = 'v$i';
      buffer.write(
          '[$previous][$i:v]xfade=transition=fade:duration=$transitionDuration:offset=$offset[$currentOutput];');
      previous = currentOutput; // Update for next iteration.
    }
    buffer.write('[$previous]format=yuv420p[v]');
    return buffer.toString();
  }

  Future<File> _getMusicFile() async {
    final byteData = await rootBundle.load('assets/bg_music.mp3');
    final tempFile = File('${(await getTemporaryDirectory()).path}/music.mp3');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());
    return tempFile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo to Video Maker'),
        titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent),
        elevation: 2,
      ),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _pickImages,
                    child: const Text(
                      'Select Images (3-5)',
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (_selectedImages.isNotEmpty)
                    Expanded(
                      child: PageView.builder(
                        itemCount: _selectedImages.length,
                        itemBuilder: (ctx, i) => Image.file(
                          File(_selectedImages[i].path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _exportVideo,
                    child: const Text(
                      'Create Video',
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
