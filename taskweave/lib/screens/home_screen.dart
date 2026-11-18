import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/todo_provider.dart';
import '../providers/sms_provider.dart';
import '../widgets/todo_list_sidebar.dart';
import '../widgets/todo_list_view.dart';
import '../widgets/sms_suggestions_sheet.dart';
import 'create_todo_screen.dart';
import 'list_settings_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUser != null) {
        context.read<TodoProvider>().initializeForUser(
              authProvider.currentUser!.uid,
            );
        context.read<SmsProvider>().checkPermission();
      }
    });
  }

  void _showSmsSuggestions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmsSuggestionsSheet(),
    );
  }

  void _showCreateListDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '📝';
    String selectedColor = 'blue';

    final emojis = ['📝', '🏠', '💼', '🛒', '🎯', '❤️', '🌟', '🎉', '🚀', '💡'];
    final colors = {
      'blue': Colors.blue,
      'green': Colors.green,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'red': Colors.red,
      'teal': Colors.teal,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'List name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Choose an emoji:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: emojis.map((e) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedEmoji = e),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selectedEmoji == e
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Choose a color:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: colors.entries.map((entry) {
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedColor = entry.key),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: selectedColor == entry.key
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context);
                await context.read<TodoProvider>().createList(
                      name: nameController.text.trim(),
                      emoji: selectedEmoji,
                      color: selectedColor,
                    );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, TodoProvider>(
      builder: (context, auth, todoProvider, _) {
        if (!auth.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              // Side drawer (always visible on wider screens, drawer on narrow)
              if (MediaQuery.of(context).size.width >= 700)
                TodoListSidebar(
                  onCreateList: _showCreateListDialog,
                ),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(
                    title: Consumer<TodoProvider>(
                      builder: (context, tp, _) => Text(
                        tp.selectedList?.name ?? 'TaskWeave',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    leading: MediaQuery.of(context).size.width < 700
                        ? Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          )
                        : null,
                    actions: [
                      Consumer<SmsProvider>(
                        builder: (context, sms, _) => Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.message_outlined),
                              tooltip: 'SMS Suggestions',
                              onPressed: _showSmsSuggestions,
                            ),
                            if (sms.hasSuggestions)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Consumer<TodoProvider>(
                        builder: (context, tp, _) {
                          if (tp.selectedList == null) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            tooltip: 'List Settings',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ListSettingsScreen(
                                    todoList: tp.selectedList!,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'sign_out') {
                            await auth.signOut();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                const Icon(Icons.person_outlined),
                                const SizedBox(width: 8),
                                Text(auth.currentUser?.name ?? 'Profile'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'sign_out',
                            child: Row(
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 8),
                                Text('Sign Out'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  drawer: MediaQuery.of(context).size.width < 700
                      ? Drawer(
                          child: TodoListSidebar(
                            onCreateList: _showCreateListDialog,
                          ),
                        )
                      : null,
                  body: const TodoListView(),
                  floatingActionButton:
                      Consumer<TodoProvider>(builder: (context, tp, _) {
                    if (tp.selectedList == null) return const SizedBox.shrink();
                    return FloatingActionButton.extended(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateTodoScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('New Task'),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
