import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

/// Widget para preview de medios (imágenes y videos)
class MediaPreview extends StatefulWidget {
  final String url;
  final String? thumbnailUrl;
  final bool isVideo;

  const MediaPreview({
    Key? key,
    required this.url,
    this.thumbnailUrl,
    this.isVideo = false,
  }) : super(key: key);

  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoController!.initialize();
      setState(() {
        _isVideoInitialized = true;
      });
    } catch (e) {
      // print('Error inicializando video: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _showFullScreenImage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(widget.url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
    );
  }

  void _showFullScreenVideo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: _videoController != null && _isVideoInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const CircularProgressIndicator(),
          ),
          floatingActionButton: _videoController != null && _isVideoInitialized
              ? FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
                  child: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isVideo) {
      return GestureDetector(
        onTap: _showFullScreenVideo,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.thumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                )
              else if (_isVideoInitialized && _videoController != null)
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
              else
                const Center(child: CircularProgressIndicator()),
              const Icon(
                Icons.play_circle_filled,
                size: 48,
                color: Colors.white,
              ),
            ],
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: _showFullScreenImage,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: widget.url,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ),
      );
    }
  }
}




