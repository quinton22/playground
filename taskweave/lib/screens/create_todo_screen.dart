import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/todo_provider.dart';
import '../models/todo_item.dart';
import '../models/sms_message.dart';

class CreateTodoScreen extends StatefulWidget {
  final TodoSuggestion? suggestion;

  const CreateTodoScreen({super.key, this.suggestion});

  @override
  State<CreateTodoScreen> createState() => _CreateTodoScreenState();
}

class _CreateTodoScreenState extends State<CreateTodoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();

  DateTime? _deadline;
  DateTime? _reminderAt;
  TodoPriority _priority = TodoPriority.medium;
  final List<String> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.suggestion != null) {
      _titleController.text = widget.suggestion!.suggestedTitle;
      _descriptionController.text =
          widget.suggestion!.suggestedDescription ?? '';
      _deadline = widget.suggestion!.suggestedDeadline;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _deadline ?? DateTime.now().add(const Duration(hours: 1))),
    );

    if (!mounted) return;

    setState(() {
      _deadline = time != null
          ? DateTime(date.year, date.month, date.day, time.hour, time.minute)
          : DateTime(date.year, date.month, date.day, 23, 59);
    });
  }

  Future<void> _pickReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderAt ?? (_deadline ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _reminderAt ?? DateTime.now().add(const Duration(hours: 1))),
    );

    if (!mounted) return;

    setState(() {
      _reminderAt = time != null
          ? DateTime(date.year, date.month, date.day, time.hour, time.minute)
          : DateTime(date.year, date.month, date.day, 9, 0);
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _createTodo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final todoProvider = context.read<TodoProvider>();
    final result = await todoProvider.createTodo(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      deadline: _deadline,
      reminderAt: _reminderAt,
      priority: _priority,
      tags: _tags,
      suggestedFromMessageId: widget.suggestion?.sourceMessageId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Task created successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(todoProvider.error ?? 'Failed to create task'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM d, y h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.suggestion != null ? '✨ Suggested Task' : 'New Task',
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createTodo,
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.suggestion != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.message_outlined,
                        color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suggested from message',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            ),
                          ),
                          Text(
                            '"${widget.suggestion!.sourceMessageSnippet}"',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onSecondaryContainer,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              autofocus: widget.suggestion == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Task title *',
                hintText: 'What needs to be done?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a task title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add more details...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Priority selector
            const Text(
              'Priority',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TodoPriority>(
              segments: const [
                ButtonSegment(
                  value: TodoPriority.low,
                  label: Text('Low'),
                  icon: Icon(Icons.arrow_downward, size: 16),
                ),
                ButtonSegment(
                  value: TodoPriority.medium,
                  label: Text('Medium'),
                  icon: Icon(Icons.remove, size: 16),
                ),
                ButtonSegment(
                  value: TodoPriority.high,
                  label: Text('High'),
                  icon: Icon(Icons.arrow_upward, size: 16),
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (selection) {
                setState(() => _priority = selection.first);
              },
            ),
            const SizedBox(height: 20),

            // Deadline
            const Text(
              'Deadline',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _deadline != null
                            ? dateFormat.format(_deadline!)
                            : 'No deadline (open-ended)',
                        style: TextStyle(
                          color: _deadline != null
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _deadline = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reminder
            const Text(
              'Reminder',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickReminder,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _reminderAt != null
                            ? dateFormat.format(_reminderAt!)
                            : 'No reminder',
                        style: TextStyle(
                          color: _reminderAt != null
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                    if (_reminderAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _reminderAt = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            const Text(
              'Tags',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: 'Add tag',
                      hintText: 'e.g. work, shopping, health',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onFieldSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
