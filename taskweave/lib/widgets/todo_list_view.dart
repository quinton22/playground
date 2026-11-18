import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/todo_provider.dart';
import '../models/todo_item.dart';
import '../screens/edit_todo_screen.dart';

class TodoListView extends StatelessWidget {
  const TodoListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, _) {
        if (todoProvider.selectedList == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.playlist_add_check,
                  size: 80,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No list selected',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create or select a list to get started',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  ),
                ),
              ],
            ),
          );
        }

        final openTodos = todoProvider.openTodos;
        final completedTodos = todoProvider.completedTodos;

        if (openTodos.isEmpty && completedTodos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'All clear! 🎉',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to add a new task',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            if (openTodos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${openTodos.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return TodoItemCard(todo: openTodos[index]);
                  },
                  childCount: openTodos.length,
                ),
              ),
            ],
            if (completedTodos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        'COMPLETED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${completedTodos.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return TodoItemCard(todo: completedTodos[index]);
                  },
                  childCount: completedTodos.length,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }
}

class TodoItemCard extends StatelessWidget {
  final TodoItem todo;

  const TodoItemCard({super.key, required this.todo});

  Color _priorityColor(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return Colors.red;
      case TodoPriority.medium:
        return Colors.orange;
      case TodoPriority.low:
        return Colors.blue;
    }
  }

  String _priorityLabel(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return 'High';
      case TodoPriority.medium:
        return 'Medium';
      case TodoPriority.low:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');
    final priorityColor = _priorityColor(todo.priority);

    return Dismissible(
      key: Key(todo.id),
      background: Container(
        color: Colors.green.withOpacity(0.85),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.check, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        color: Colors.red.withOpacity(0.85),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Toggle complete
          await context.read<TodoProvider>().toggleTodo(todo);
          return false; // Don't actually dismiss, Firestore stream will update
        } else {
          // Delete confirmation
          return await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete Task'),
              content: Text('Delete "${todo.title}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          context.read<TodoProvider>().deleteTodo(todo);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: todo.isOverdue
                ? Colors.red.withOpacity(0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditTodoScreen(todo: todo),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: GestureDetector(
                    onTap: () =>
                        context.read<TodoProvider>().toggleTodo(todo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: todo.isCompleted
                            ? Colors.green
                            : Colors.transparent,
                        border: Border.all(
                          color: todo.isCompleted
                              ? Colors.green
                              : priorityColor,
                          width: 2,
                        ),
                      ),
                      child: todo.isCompleted
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: todo.isCompleted
                              ? colorScheme.onSurface.withOpacity(0.5)
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (todo.description != null &&
                          todo.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          todo.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Priority badge
                          _Badge(
                            label: _priorityLabel(todo.priority),
                            color: priorityColor.withOpacity(0.15),
                            textColor: priorityColor,
                          ),
                          // Deadline
                          if (todo.hasDeadline)
                            _Badge(
                              label: todo.isOverdue
                                  ? '⚠️ Overdue: ${dateFormat.format(todo.deadline!)}'
                                  : '📅 ${dateFormat.format(todo.deadline!)}',
                              color: todo.isOverdue
                                  ? Colors.red.withOpacity(0.15)
                                  : colorScheme.tertiaryContainer
                                      .withOpacity(0.5),
                              textColor: todo.isOverdue
                                  ? Colors.red
                                  : colorScheme.tertiary,
                            ),
                          // Reminder
                          if (todo.hasReminder)
                            _Badge(
                              label:
                                  '🔔 ${timeFormat.format(todo.reminderAt!)}',
                              color:
                                  colorScheme.secondaryContainer.withOpacity(0.5),
                              textColor: colorScheme.secondary,
                            ),
                          // Suggested from SMS
                          if (todo.suggestedFromMessageId != null)
                            _Badge(
                              label: '💬 From message',
                              color: Colors.purple.withOpacity(0.1),
                              textColor: Colors.purple,
                            ),
                          // Tags
                          ...todo.tags.map((tag) => _Badge(
                                label: tag,
                                color: colorScheme.surfaceContainerHighest,
                                textColor:
                                    colorScheme.onSurface.withOpacity(0.7),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
