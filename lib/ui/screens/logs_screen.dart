import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/providers/logs_provider.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _filterLevel = 'all';
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // Start polling logs when screen is opened (ensures it's running)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logsProvider = context.read<LogsProvider>();
      logsProvider.startBackendPolling();
    });
  }

  @override
  void dispose() {
    // We don't stop polling here anymore because we want logs to continue
    // being captured in the background for the entire app session.
    // if (mounted) {
    //   context.read<LogsProvider>().stopPolling();
    // }
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return Colors.red;
      case 'warn':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'debug':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Logs'),
        backgroundColor: const Color(0xFF1a1a1a),
        elevation: 0,
        actions: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: _filterLevel,
              dropdownColor: const Color(0xFF2a2a2a),
              style: const TextStyle(color: Colors.white),
              underline: Container(height: 2, color: Colors.blue),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Levels')),
                DropdownMenuItem(value: 'error', child: Text('Errors')),
                DropdownMenuItem(value: 'warn', child: Text('Warnings')),
                DropdownMenuItem(value: 'info', child: Text('Info')),
                DropdownMenuItem(value: 'debug', child: Text('Debug')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filterLevel = value);
                }
              },
            ),
          ),
          // Auto-scroll toggle
          Tooltip(
            message: 'Auto-scroll to latest logs',
            child: IconButton(
              icon: Icon(
                _autoScroll ? Icons.arrow_downward : Icons.arrow_upward,
                color: _autoScroll ? Colors.green : Colors.grey,
              ),
              onPressed: () {
                setState(() => _autoScroll = !_autoScroll);
              },
            ),
          ),
          // Clear logs button
          Tooltip(
            message: 'Clear all logs',
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Logs?'),
                    content: const Text(
                      'Are you sure you want to clear all logs?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<LogsProvider>().clearLogs();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: const Color(0xFF0a0a0a),
        child: Consumer<LogsProvider>(
          builder: (context, logsProvider, _) {
            final allLogs = logsProvider.logs;
            final logs =
                _filterLevel == 'all'
                    ? allLogs
                    : allLogs
                        .where(
                          (l) =>
                              l.level.toLowerCase() ==
                              _filterLevel.toLowerCase(),
                        )
                        .toList();

            if (logs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info, size: 64, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text(
                      'No logs available',
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                    if (logsProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });

            return ListView.builder(
              controller: _scrollController,
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final timestamp = DateFormat(
                  'HH:mm:ss.SSS',
                ).format(DateTime.parse(log.timestamp));
                final levelColor = _getLevelColor(log.level);

                return Container(
                  color: log.level.toLowerCase() == 'error'
                      ? Colors.red.withOpacity(0.1)
                      : log.level.toLowerCase() == 'warn'
                      ? Colors.orange.withOpacity(0.05)
                      : Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamp
                        SizedBox(
                          width: 120,
                          child: Text(
                            timestamp,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: levelColor.withOpacity(0.2),
                            border: Border.all(color: levelColor, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.level.toUpperCase(),
                            style: TextStyle(
                              color: levelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Message
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (log.source != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '(${log.source})',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
