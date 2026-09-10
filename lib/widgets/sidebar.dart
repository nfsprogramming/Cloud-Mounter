import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'provider_icon.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsProvider);
    final selectedId = ref.watch(selectedConnectionIdProvider);

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          _SidebarHeader(),

          // Connection list
          Expanded(
            child: connectionsAsync.when(
              data: (connections) => connections.isEmpty
                  ? _EmptySidebar()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: connections.length,
                      itemBuilder: (context, index) {
                        final conn = connections[index];
                        return _ConnectionTile(
                          conn: conn,
                          isSelected: conn.id == selectedId,
                          onTap: () {
                            ref
                                .read(selectedConnectionIdProvider.notifier)
                                .select(conn.id);
                          },
                          onMount: () => ref
                              .read(connectionsProvider.notifier)
                              .mountConnection(conn.id),
                          onUnmount: () => ref
                              .read(connectionsProvider.notifier)
                              .unmountConnection(conn.id),
                          onDelete: () => _confirmDelete(context, ref, conn),
                        );
                      },
                    ),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accent,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error loading connections',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.error),
                ),
              ),
            ),
          ),

          // Add button
          _AddConnectionButton(),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, ConnectionModel conn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Delete "${conn.name}"?'),
        content: const Text(
            'This will remove the connection and all stored credentials.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(connectionsProvider.notifier).deleteConnection(conn.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'CloudMounter',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }
}

class _ConnectionTile extends StatefulWidget {
  final ConnectionModel conn;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onMount;
  final VoidCallback onUnmount;
  final VoidCallback onDelete;

  const _ConnectionTile({
    required this.conn,
    required this.isSelected,
    required this.onTap,
    required this.onMount,
    required this.onUnmount,
    required this.onDelete,
  });

  @override
  State<_ConnectionTile> createState() => _ConnectionTileState();
}

class _ConnectionTileState extends State<_ConnectionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final conn = widget.conn;
    return GestureDetector(
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.accent.withValues(alpha: 0.15)
                : _hovered
                    ? AppTheme.cardHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: widget.isSelected
                ? Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  ProviderIcon(type: conn.type, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conn.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: widget.isSelected
                                          ? AppTheme.accentLight
                                          : AppTheme.textPrimary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conn.isEncrypted)
                              const Icon(Icons.lock,
                                  size: 12, color: AppTheme.textSecondary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              conn.type.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                            if (conn.isMounted && conn.mountPoint != null) ...[
                              const Text(' · ',
                                  style: TextStyle(
                                      color: AppTheme.textTertiary,
                                      fontSize: 11)),
                              Flexible(
                                child: Text(
                                  conn.mountPoint!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppTheme.success),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  StatusDot(
                      isMounted: conn.isMounted, isMounting: conn.isMounting),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final conn = widget.conn;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      items: [
        if (!conn.isMounted && !conn.isMounting)
          const PopupMenuItem(value: 'mount', child: Text('Mount')),
        if (conn.isMounted)
          const PopupMenuItem(value: 'unmount', child: Text('Unmount')),
        if (conn.isMounted && conn.mountPoint != null)
          const PopupMenuItem(
              value: 'open', child: Text('Open in Explorer')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );

    if (result == 'mount') widget.onMount();
    if (result == 'unmount') widget.onUnmount();
    if (result == 'delete') widget.onDelete();
    if (result == 'open' && conn.mountPoint != null) {
      _openInExplorer(conn.mountPoint!);
    }
  }

  Future<void> _openInExplorer(String path) async {
    try {
      // For Windows drive letters (e.g., G:), ensure trailing backslash so explorer opens the root
      final normalizedPath = (Platform.isWindows && RegExp(r'^[a-zA-Z]:$').hasMatch(path))
          ? '$path\\'
          : path;
      await Process.run('explorer', [normalizedPath]);
    } catch (e) {
      debugPrint('Failed to open explorer: $e');
    }
  }
}

class _EmptySidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off,
              size: 40, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No connections yet',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _AddConnectionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/add-connection'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Connection'),
        ),
      ),
    );
  }
}
