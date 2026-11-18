import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/todo_provider.dart';
import '../models/todo_list.dart';

class TodoListSidebar extends StatelessWidget {
  final VoidCallback onCreateList;

  const TodoListSidebar({super.key, required this.onCreateList});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 280,
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'TaskWeave',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<TodoProvider>(
              builder: (context, todoProvider, _) {
                final lists = todoProvider.lists;

                if (lists.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.playlist_add,
                            size: 48,
                            color: colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No lists yet',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    final isSelected = list.id == todoProvider.selectedListId;
                    final todos = todoProvider.getTodosForList(list.id);
                    final openCount =
                        todos.where((t) => !t.isCompleted).length;

                    return _ListTile(
                      todoList: list,
                      isSelected: isSelected,
                      openCount: openCount,
                      onTap: () {
                        todoProvider.selectList(list.id);
                        // Close drawer on mobile
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCreateList,
                icon: const Icon(Icons.add),
                label: const Text('New List'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  final TodoList todoList;
  final bool isSelected;
  final int openCount;
  final VoidCallback onTap;

  const _ListTile({
    required this.todoList,
    required this.isSelected,
    required this.openCount,
    required this.onTap,
  });

  Color _parseColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (todoList.color) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'red':
        return Colors.red;
      case 'teal':
        return Colors.teal;
      default:
        return colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listColor = _parseColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Text(
          todoList.emoji ?? '📝',
          style: const TextStyle(fontSize: 20),
        ),
        title: Text(
          todoList.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: openCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : listColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$openCount',
                  style: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
