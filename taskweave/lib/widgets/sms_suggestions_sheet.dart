import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sms_provider.dart';
import '../models/sms_message.dart';
import '../screens/create_todo_screen.dart';

class SmsSuggestionsSheet extends StatefulWidget {
  const SmsSuggestionsSheet({super.key});

  @override
  State<SmsSuggestionsSheet> createState() => _SmsSuggestionsSheetState();
}

class _SmsSuggestionsSheetState extends State<SmsSuggestionsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final smsProvider = context.read<SmsProvider>();
      if (smsProvider.hasPermission) {
        smsProvider.loadAndAnalyzeMessages();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const Text(
                      '💬 Smart Suggestions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Consumer<SmsProvider>(
                      builder: (context, sms, _) {
                        if (!sms.isLoading) {
                          return IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: sms.hasPermission
                                ? () => sms.loadAndAnalyzeMessages()
                                : null,
                            tooltip: 'Refresh',
                          );
                        }
                        return const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<SmsProvider>(
                  builder: (context, smsProvider, _) {
                    if (!smsProvider.hasPermission) {
                      return _PermissionView(
                        onRequestPermission: () async {
                          final granted =
                              await smsProvider.requestPermission();
                          if (granted) {
                            smsProvider.loadAndAnalyzeMessages();
                          }
                        },
                      );
                    }

                    if (smsProvider.isLoading) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Scanning your messages for todos...'),
                          ],
                        ),
                      );
                    }

                    if (smsProvider.suggestions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No suggestions found',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'TaskWeave analyzes your recent messages\nto find potential todos.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: smsProvider.suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = smsProvider.suggestions[index];
                        return _SuggestionCard(
                          suggestion: suggestion,
                          onAccept: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateTodoScreen(
                                  suggestion: suggestion,
                                ),
                              ),
                            );
                          },
                          onDismiss: () =>
                              smsProvider.dismissSuggestion(index),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionView extends StatelessWidget {
  final VoidCallback onRequestPermission;

  const _PermissionView({required this.onRequestPermission});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sms_outlined,
              size: 48,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Smart SMS Analysis',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TaskWeave can read your recent text messages and suggest todos based on what you need to do. '
            'Your messages stay private and are only analyzed on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRequestPermission,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Allow SMS Access'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Android only — iOS does not allow apps to read SMS',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final TodoSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _SuggestionCard({
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final confidencePct = (suggestion.confidence * 100).round();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion.suggestedTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _confidenceColor(suggestion.confidence)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$confidencePct%',
                    style: TextStyle(
                      fontSize: 11,
                      color: _confidenceColor(suggestion.confidence),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (suggestion.suggestedDeadline != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14,
                      color: colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Suggested deadline: ${_formatDate(suggestion.suggestedDeadline!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.format_quote,
                      size: 14,
                      color: colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      suggestion.sourceMessageSnippet,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.add_task, size: 18),
                    label: const Text('Add as Task'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.4) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
