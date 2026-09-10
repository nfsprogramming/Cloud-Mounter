import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/drive_detail_panel.dart';
import '../widgets/activity_log_panel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _logExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Trigger health check stream
    ref.watch(rcloneHealthProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Top title bar
          _TitleBar(),

          // Main content area
          Expanded(
            child: Row(
              children: [
                const Sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      const Expanded(child: DriveDetailPanel()),
                      ActivityLogPanel(
                        expanded: _logExpanded,
                        onToggle: () =>
                            setState(() => _logExpanded = !_logExpanded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(connectionsProvider).value ?? [];
    final mountedCount = connections.where((c) => c.isMounted).length;

    return Container(
      height: 40,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // drag region placeholder
          const Expanded(child: SizedBox()),

          if (mountedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$mountedCount mounted',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.success,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),

          const SizedBox(width: 12),

          if (connections.isNotEmpty && mountedCount < connections.length)
            TextButton.icon(
              onPressed: () => ref.read(connectionsProvider.notifier).mountAll(),
              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
              label: const Text('Mount All'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),

          const SizedBox(width: 8),

          // Settings icon
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/settings'),
            icon: const Icon(Icons.settings_outlined, size: 17),
            color: AppTheme.textSecondary,
            tooltip: 'Settings',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
