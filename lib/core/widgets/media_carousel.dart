import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_colors.dart';

/// Returns true if the URL points to a video file (mp4 or webm).
bool _isVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.webm');
}

/// A swipeable media carousel that displays a list of image and video URLs.
///
/// Videos are loaded lazily — only the currently-visible slide initializes a
/// [VideoPlayerController]. Controllers are disposed when the user swipes away.
class MediaCarousel extends StatefulWidget {
  final List<String> mediaUrls;
  final double height;
  final BorderRadius? borderRadius;
  /// If false, video slides start paused (recommended for list cards).
  final bool autoPlayVideo;

  const MediaCarousel({
    super.key,
    required this.mediaUrls,
    this.height = 240,
    this.borderRadius,
    this.autoPlayVideo = true,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.mediaUrls;

    if (urls.isEmpty) {
      return _FallbackPlaceholder(height: widget.height, borderRadius: widget.borderRadius);
    }

    // Single item — skip PageView overhead
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: _isVideoUrl(urls.first)
              ? _VideoSlide(
                  url: urls.first,
                  isVisible: true,
                  autoPlay: widget.autoPlayVideo,
                )
              : _ImageSlide(url: urls.first),
        ),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                final url = urls[i];
                if (_isVideoUrl(url)) {
                  return _VideoSlide(
                    url: url,
                    isVisible: _currentIndex == i,
                    autoPlay: widget.autoPlayVideo,
                  );
                }
                return _ImageSlide(url: url);
              },
            ),
            // Dot indicator
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? Colors.white
                          : Colors.white.withAlpha(120),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image slide ─────────────────────────────────────────────────────────────

class _ImageSlide extends StatelessWidget {
  final String url;
  const _ImageSlide({required this.url});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => Container(color: AppColors.borderLight),
        errorWidget: (_, _, _) => Container(
          color: AppColors.primaryBlue.withAlpha(15),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: AppColors.textLight, size: 32),
          ),
        ),
      );
}

// ── Video slide ─────────────────────────────────────────────────────────────

class _VideoSlide extends StatefulWidget {
  final String url;
  final bool isVisible;
  final bool autoPlay;
  const _VideoSlide({required this.url, required this.isVisible, this.autoPlay = true});

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitializing = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) _initVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      // Swiped TO this slide → init
      _initVideo();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      // Swiped AWAY from this slide → release
      _disposeVideo();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (_isInitializing || _videoController != null) return;
    _isInitializing = true;
    _hasError = false;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      // 10-second timeout: if CDN is slow, gracefully fall back instead of hanging forever
      await controller.initialize().timeout(const Duration(seconds: 10));

      if (!mounted) {
        controller.dispose();
        return;
      }

      _videoController = controller;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: widget.autoPlay,
        looping: true,
        showControls: true,
        // Start muted — respectful UX; user can tap to unmute
        allowMuting: true,
        showOptions: false,
        // Compact controls for a carousel slide
        allowFullScreen: false,
      );
      // Start muted
      controller.setVolume(0);

      setState(() => _isInitializing = false);
    } catch (e) {
      debugPrint('MediaCarousel: Video init failed for ${widget.url}: $e');
      _disposeVideo();
      if (mounted) setState(() { _hasError = true; _isInitializing = false; });
    }
  }

  void _disposeVideo() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 32),
              SizedBox(height: 6),
              Text('Video unavailable', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_isInitializing || _chewieController == null) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Chewie(controller: _chewieController!),
    );
  }
}

// ── Fallback placeholder ────────────────────────────────────────────────────

class _FallbackPlaceholder extends StatelessWidget {
  final double height;
  final BorderRadius? borderRadius;
  const _FallbackPlaceholder({required this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Container(
          height: height,
          width: double.infinity,
          color: AppColors.primaryBlue.withAlpha(15),
          child: const Center(
            child: Icon(Icons.photo_library_rounded, color: AppColors.primaryBlue, size: 44),
          ),
        ),
      );
}
