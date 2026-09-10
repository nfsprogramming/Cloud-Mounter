
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/connection_model.dart';
import '../providers/app_providers.dart';
import '../services/rclone_service.dart';
import '../theme/app_theme.dart';
import 'provider_icon.dart';

class DriveDetailPanel extends ConsumerWidget {
  const DriveDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(selectedConnectionProvider);

    if (conn == null) {
      return _EmptyPanel();
    }

    return _ConnectionDetail(conn: conn, ref: ref);
  }
}

class _EmptyPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/icons/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select a connection',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a cloud drive or server from the sidebar',
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

class _ConnectionDetail extends StatelessWidget {
  final ConnectionModel conn;
  final WidgetRef ref;

  const _ConnectionDetail({required this.conn, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          _HeaderCard(conn: conn, ref: ref),
          const SizedBox(height: 24),

          // Config details
          _DetailsCard(conn: conn),
          const SizedBox(height: 24),

          // Storage details (only when mounted)
          if (conn.isMounted) ...[
            _StorageCard(conn: conn),
            const SizedBox(height: 24),
          ],

          // Folder browser
          if (conn.isMounted) _FolderBrowser(conn: conn),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ConnectionModel conn;
  final WidgetRef ref;

  const _HeaderCard({required this.conn, required this.ref});

  @override
  Widget build(BuildContext context) {
    final color =
        AppTheme.providerColors[conn.type.name] ?? AppTheme.accent;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        gradient: conn.isMounted
            ? LinearGradient(
                colors: [
                  AppTheme.success.withValues(alpha: 0.05),
                  AppTheme.card,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProviderIcon(type: conn.type, size: 56),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conn.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (conn.isEncrypted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock,
                                size: 12, color: AppTheme.warning),
                            const SizedBox(width: 4),
                            Text(
                              'Encrypted',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppTheme.warning),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        conn.type.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusDot(
                        isMounted: conn.isMounted,
                        isMounting: conn.isMounting),
                    const SizedBox(width: 6),
                    Text(
                      conn.isMounting
                          ? 'Mounting…'
                          : conn.isMounted
                              ? 'Mounted at ${conn.mountPoint}'
                              : 'Not mounted',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: conn.isMounted
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
                if (conn.lastMounted != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last mounted: ${_formatDate(conn.lastMounted!)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.textTertiary),
                  ),
                ],
                if (conn.mountError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 14, color: AppTheme.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            conn.mountError!,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Mount/Unmount button
          _MountButton(conn: conn, ref: ref),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MountButton extends StatelessWidget {
  final ConnectionModel conn;
  final WidgetRef ref;

  const _MountButton({required this.conn, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (conn.isMounting) {
      return SizedBox(
        width: 140,
        height: 40,
        child: OutlinedButton(
          onPressed: null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent),
              ),
              const SizedBox(width: 8),
              const Text('Mounting'),
            ],
          ),
        ),
      );
    }

    if (conn.isMounted) {
      return SizedBox(
        width: 140,
        height: 40,
        child: OutlinedButton.icon(
          onPressed: () => ref
              .read(connectionsProvider.notifier)
              .unmountConnection(conn.id),
          icon: const Icon(Icons.eject, size: 16),
          label: const Text('Unmount'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    return SizedBox(
      width: 140,
      height: 40,
      child: ElevatedButton.icon(
        onPressed: () => ref
            .read(connectionsProvider.notifier)
            .mountConnection(conn.id),
        icon: const Icon(Icons.cloud_upload, size: 16),
        label: const Text('Mount'),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final ConnectionModel conn;

  const _DetailsCard({required this.conn});

  @override
  Widget build(BuildContext context) {
    final config = conn.config;
    final entries = config.entries
        .where((e) => !['password', 'secret', 'key'].any(
            (s) => e.key.toLowerCase().contains(s)))
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Details',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        _formatKey(e.key),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _StorageCard extends ConsumerWidget {
  final ConnectionModel conn;

  const _StorageCard({required this.conn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(storageProvider(conn.id));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Storage Usage',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              storageAsync.when(
                data: (data) => data.isEmpty
                    ? const SizedBox()
                    : Text(
                        '${data['count']} files',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                      ),
                loading: () => const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppTheme.textTertiary),
                ),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          storageAsync.when(
            data: (data) {
              if (data.isEmpty) {
                return _buildEmptyStorage(context);
              }

              final used = (data['bytes'] as num?)?.toInt() ?? 0;
              final total = (data['total'] as num?)?.toInt() ?? 0;
              final free = (data['free'] as num?)?.toInt() ?? 0;

              // If total is 0, we can't show a progress bar (unlimited/unknown)
              final hasQuota = total > 0;
              final percent = hasQuota ? (used / total).clamp(0.0, 1.0) : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasQuota) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 8,
                        backgroundColor: AppTheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percent > 0.9 ? AppTheme.error : AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatBytes(used),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Used space',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      if (hasQuota)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatBytes(total),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Total quota',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        )
                      else if (free > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatBytes(free),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Available space',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              );
            },
            loading: () => _buildLoadingStorage(context),
            error: (e, _) => Text('Error fetching storage: $e',
                style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStorage(BuildContext context) {
    return Text(
      'Retrieving storage information...',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppTheme.textTertiary),
    );
  }

  Widget _buildLoadingStorage(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
            minHeight: 8,
            backgroundColor: AppTheme.surface,
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.accent),
          ),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var i = 0;
  double d = bytes.toDouble();
  while (d >= 1024 && i < suffixes.length - 1) {
    d /= 1024;
    i++;
  }
  return '${d.toStringAsFixed(d < 10 ? 1 : 0)} ${suffixes[i]}';
}

class _FolderBrowser extends StatefulWidget {
  final ConnectionModel conn;

  const _FolderBrowser({required this.conn});

  @override
  State<_FolderBrowser> createState() => _FolderBrowserState();
}

class _FolderBrowserState extends State<_FolderBrowser> {
  List<String>? _folders;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _loading = true);
    try {
      final remoteName =
          'cm_${widget.conn.id.replaceAll('-', '_')}';
      final folders = await RcloneService.listRemoteFolders(
        remoteName,
        isEncrypted: widget.conn.isEncrypted,
      );
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _folders = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Top-level Folders',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadFolders,
                icon: const Icon(Icons.refresh, size: 16),
                color: AppTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.accent),
            )
          else if (_folders == null || _folders!.isEmpty)
            Text(
              'No folders found',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textTertiary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _folders!
                  .map((folder) => _FolderChip(folder: folder))
                  .toList()
                  .animate(interval: 50.ms)
                  .fadeIn()
                  .slideX(begin: -0.1),
            ),
        ],
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  final String folder;

  const _FolderChip({required this.folder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder, size: 14, color: AppTheme.warning),
          const SizedBox(width: 6),
          Text(
            folder,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
