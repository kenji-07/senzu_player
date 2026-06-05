import 'package:flutter/material.dart';
import 'package:senzu_player/senzu_player.dart';
import 'offline_player_page.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final List<DownloadTask> _tasks = [];
  bool _isLoading = true;

  final _urlController = TextEditingController(
    text: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  );
  final _titleController = TextEditingController(text: 'Senzu Test Video');
  final _descController =
      TextEditingController(text: 'HLS adaptive streaming test video.');
  final _posterController = TextEditingController(
    text: 'https://image.tmdb.org/t/p/original/aWM8eYmhqBgH4YC5WLLPTJxlc2t.jpg',
  );
  final _subUrlController = TextEditingController(
    text: 'https://vjs.zencdn.net/v/oceans.vtt',
  );
  final _subKeyController =
      TextEditingController(text: '0123456789abcdef0123456789abcdef');
  final _subIvController =
      TextEditingController(text: 'abcdef0123456789abcdef0123456789');

  @override
  void initState() {
    super.initState();
    _loadTasks();
    SenzuDownloader.instance.requestNotificationPermission();
    SenzuDownloader.instance.onProgressChanged
        .listen((DownloadTask updatedTask) {
      if (mounted) {
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
          if (index != -1) {
            if (updatedTask.status == 'deleted' ||
                updatedTask.status == 'cancelled') {
              _tasks.removeAt(index);
            } else {
              _tasks[index] = updatedTask;
            }
          } else if (updatedTask.status != 'deleted' &&
              updatedTask.status != 'cancelled') {
            _tasks.add(updatedTask);
          }
        });
      }
    });

    // Check offline licenses expiration periodically
    SenzuDownloader.instance.checkLicenses();
  }

  Future<void> _loadTasks() async {
    final tasks = await SenzuDownloader.instance.getAllTasks();
    if (mounted) {
      setState(() {
        _tasks.clear();
        _tasks.addAll(tasks);
        _isLoading = false;
      });
    }
  }

  void _showAddDownloadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16161C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Download video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(_titleController, 'Title'),
                _buildTextField(_descController, 'Description'),
                _buildTextField(_urlController, 'Video URL (HLS / MP4)'),
                _buildTextField(_posterController, 'Image URL (Poster)'),
                _buildTextField(_subUrlController, 'Subtitle URL (VTT/SRT)'),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            _subKeyController, 'Subtitle Key (HEX)')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField(
                            _subIvController, 'Subtitle IV (HEX)')),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4444),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final id = DateTime.now().millisecondsSinceEpoch.toString();

                    // Simple license expiration configured to 1 day from now for testing expiration alerts
                    final expiredAt = DateTime.now()
                        .add(const Duration(days: 1))
                        .toIso8601String();

                    final url = _urlController.text.trim();
                    final title = _titleController.text.trim();
                    final description = _descController.text.trim();
                    final posterUrl = _posterController.text.trim();
                    final subtitleUrl = _subUrlController.text.trim().isEmpty
                        ? null
                        : _subUrlController.text.trim();
                    final subtitleKey = _subKeyController.text.trim().isEmpty
                        ? null
                        : _subKeyController.text.trim();
                    final subtitleIv = _subIvController.text.trim().isEmpty
                        ? null
                        : _subIvController.text.trim();

                    Navigator.pop(context);

                    if (url.contains('.m3u8')) {
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      try {
                        final sources =
                            await VideoSource.fromM3u8PlaylistUrl(url);
                        if (context.mounted) {
                          Navigator.pop(context); // Dismiss loading dialog
                        }

                        if (sources.length > 1) {
                          // Show quality selection dialog
                          if (context.mounted) {
                            final selectedQuality = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                return SimpleDialog(
                                  backgroundColor: const Color(0xFF16161E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.1)),
                                  ),
                                  titlePadding:
                                      const EdgeInsets.fromLTRB(24, 24, 24, 8),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.hd, color: Color(0xFFFF4444)),
                                      SizedBox(width: 8),
                                      Text(
                                        'Choose your download quality.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: sources.keys.map((quality) {
                                    return SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(context, quality),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              quality,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.download_for_offline,
                                              color: Colors.white30,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            );

                            if (selectedQuality != null &&
                                sources[selectedQuality] != null) {
                              final finalUrl =
                                  sources[selectedQuality]!.dataSource;
                              final finalTitle = '$title ($selectedQuality)';
                              SenzuDownloader.instance.startDownload(
                                id: id,
                                url: finalUrl,
                                title: finalTitle,
                                description: description,
                                posterUrl: posterUrl,
                                subtitleUrl: subtitleUrl,
                                subtitleKey: subtitleKey,
                                subtitleIv: subtitleIv,
                                expiredAt: expiredAt,
                              );
                              return;
                            }
                          }
                        }
                      } catch (e) {
                        debugPrint('Error parsing HLS playlist: $e');
                        if (context.mounted) {
                          Navigator.pop(context); // Dismiss loading dialog
                        }
                      }
                    }

                    // Fallback to downloading direct url
                    SenzuDownloader.instance.startDownload(
                      id: id,
                      url: url,
                      title: title,
                      description: description,
                      posterUrl: posterUrl,
                      subtitleUrl: subtitleUrl,
                      subtitleKey: subtitleKey,
                      subtitleIv: subtitleIv,
                      expiredAt: expiredAt,
                    );
                  },
                  child: const Text(
                    'Start downloading',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF22222E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.add_circle_outline, color: Color(0xFFFF4444)),
            onPressed: _showAddDownloadDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_for_offline_outlined,
              size: 80, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            'No videos downloaded.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4444).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFFFF4444),
              side: const BorderSide(color: Color(0xFFFF4444), width: 1),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add new'),
            onPressed: _showAddDownloadDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DownloadTask task) {
    final bool isCompleted = task.status == 'completed';
    final bool isDownloading = task.status == 'downloading';
    final bool isPaused = task.status == 'paused';
    final bool isFailed = task.status == 'failed';
    final bool isExpired = task.status == 'expired';

    Color statusColor = Colors.white54;
    String statusText = task.status;
    if (isCompleted) {
      statusColor = Colors.green;
      statusText = 'Completed';
    } else if (isDownloading) {
      statusColor = Colors.blue;
      statusText = 'Downloading';
    } else if (isPaused) {
      statusColor = Colors.orange;
      statusText = 'Paused';
    } else if (isFailed) {
      statusColor = Colors.red;
      statusText = 'Failed';
    } else if (isExpired) {
      statusColor = Colors.purple;
      statusText = 'Expired';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isCompleted
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OfflinePlayerPage(task: task),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail poster image
                Container(
                  width: 100,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white10,
                    image: task.posterUrl != null && task.posterUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(task.posterUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: task.posterUrl == null || task.posterUrl!.isEmpty
                      ? const Icon(Icons.video_library, color: Colors.white30)
                      : null,
                ),
                const SizedBox(width: 12),
                // Task information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Progress bar or stats
                      if (!isCompleted && !isExpired && !isFailed) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: task.progress / 100.0,
                            backgroundColor: Colors.white10,
                            valueColor:
                                const AlwaysStoppedAnimation(Color(0xFFFF4444)),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isDownloading && task.speedText.isNotEmpty
                                  ? '$statusText (${task.speedText})'
                                  : statusText,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              task.progressSizeText.isNotEmpty
                                  ? '${task.progressSizeText} (${task.progress.toStringAsFixed(1)}%)'
                                  : '${task.progress.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isCompleted &&
                                task.completedSizeText.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                task.completedSizeText,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 10),
                              ),
                            ],
                            const SizedBox(width: 8),
                            if (isCompleted)
                              const Text(
                                'Play',
                                style: TextStyle(
                                    color: Colors.white30, fontSize: 10),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Controls
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDownloading)
                      IconButton(
                        icon: const Icon(Icons.pause_circle_outline,
                            color: Colors.orange, size: 24),
                        onPressed: () =>
                            SenzuDownloader.instance.pauseDownload(task.id),
                      ),
                    if (isPaused)
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline,
                            color: Colors.blue, size: 24),
                        onPressed: () =>
                            SenzuDownloader.instance.resumeDownload(task.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white30, size: 20),
                      onPressed: () =>
                          SenzuDownloader.instance.deleteDownload(task.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
