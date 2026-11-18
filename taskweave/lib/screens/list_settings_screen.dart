import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/todo_provider.dart';
import '../models/todo_list.dart';

class ListSettingsScreen extends StatefulWidget {
  final TodoList todoList;

  const ListSettingsScreen({super.key, required this.todoList});

  @override
  State<ListSettingsScreen> createState() => _ListSettingsScreenState();
}

class _ListSettingsScreenState extends State<ListSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final _inviteEmailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.todoList.name);
    _descriptionController =
        TextEditingController(text: widget.todoList.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final updatedList = widget.todoList.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    final success =
        await context.read<TodoProvider>().updateList(updatedList);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'List updated!' : 'Failed to update list'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _inviteMember() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty) return;
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await context
        .read<TodoProvider>()
        .inviteMember(widget.todoList.id, email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    _inviteEmailController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '📨 Invite sent to $email!'
            : 'Failed to send invite'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text(
          'Are you sure you want to delete "${widget.todoList.name}"? '
          'All tasks in this list will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context
        .read<TodoProvider>()
        .deleteList(widget.todoList.id);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('List deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = context.read<AuthProvider>();
    final isOwner =
        widget.todoList.isOwner(authProvider.currentUser?.uid ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('List Settings'),
        actions: [
          if (isOwner)
            TextButton(
              onPressed: _isLoading ? null : _saveSettings,
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // List details section
          _SectionHeader(title: 'List Details'),
          const SizedBox(height: 8),
          if (isOwner) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'List Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            ListTile(
              title: Text(widget.todoList.name),
              subtitle: widget.todoList.description != null
                  ? Text(widget.todoList.description!)
                  : null,
            ),
          ],

          const SizedBox(height: 24),

          // Members section
          _SectionHeader(title: '👥 Members'),
          const SizedBox(height: 8),

          // Owner
          _MemberTile(
            uid: widget.todoList.ownerId,
            label: 'Owner',
            labelColor: colorScheme.primary,
            canRemove: false,
            onRemove: null,
          ),

          // Members
          ...widget.todoList.memberIds.map((memberId) {
            return _MemberTile(
              uid: memberId,
              label: 'Member',
              labelColor: colorScheme.secondary,
              canRemove: isOwner,
              onRemove: isOwner
                  ? () async {
                      final tp = context.read<TodoProvider>();
                      final updatedList = widget.todoList.copyWith(
                        memberIds: List.from(widget.todoList.memberIds)
                          ..remove(memberId),
                      );
                      await tp.updateList(updatedList);
                    }
                  : null,
            );
          }),

          // Pending invites
          if (widget.todoList.pendingInvites.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Pending Invites',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            ...widget.todoList.pendingInvites.map((email) {
              return ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(email),
                trailing: isOwner
                    ? IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: () async {
                          final tp = context.read<TodoProvider>();
                          final updatedList = widget.todoList.copyWith(
                            pendingInvites:
                                List.from(widget.todoList.pendingInvites)
                                  ..remove(email),
                          );
                          await tp.updateList(updatedList);
                        },
                      )
                    : null,
              );
            }),
          ],

          if (isOwner) ...[
            const SizedBox(height: 16),
            _SectionHeader(title: '📨 Invite Someone'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inviteEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'friend@example.com',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    onSubmitted: (_) => _inviteMember(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _inviteMember,
                  icon: const Icon(Icons.send),
                  label: const Text('Invite'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ],

          if (isOwner) ...[
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Danger Zone',
              color: colorScheme.error,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _deleteList,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete this list'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String uid;
  final String label;
  final Color labelColor;
  final bool canRemove;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.uid,
    required this.label,
    required this.labelColor,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(uid.isNotEmpty ? uid[0].toUpperCase() : '?'),
      ),
      title: Text(uid),
      subtitle: Text(label, style: TextStyle(color: labelColor)),
      trailing: canRemove
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemove,
            )
          : null,
    );
  }
}
