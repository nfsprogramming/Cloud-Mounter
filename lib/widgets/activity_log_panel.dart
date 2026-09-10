import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_log_model.dart';
import '../providers/app_providers.dart';
import '../services/connection_service.dart';
import '../theme/app_theme.dart';

class ActivityLogPanel extends ConsumerStatefulWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const ActivityLogPanel(
      {super.key, required this.expanded, required this.onToggle});

  @override
  ConsumerState<ActivityLogPanel> createState() => _ActivityLogPanelState();
}

class _ActivityLogPanelState extends ConsumerState<ActivityLogPanel> {
  String? _filterConnId;
  LogEventType? _filterType;
  bool _exporting = false;

  static const Color _panelBg = Color(0xFF111113);

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogProvider);
    final statsAsync = ref.watch(rcloneStatsProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: widget.expanded ? 260 : 42,
      decoration: const BoxDecoration(
        color: _panelBg,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header bar
          _PanelHeader(
            expanded: widget.expanded,
            onToggle: widget.onToggle,
            statsAsync: statsAsync,
            onExport: _export,
            exporting: _exporting,
            filterType: _filterType,
            onFilterType: (t) {
              setState(() => _filterType = t);
              ref
                  .read(activityLogProvider.notifier)
                  .refresh(connId: _filterConnId, type: _filterType);
            },
          ),

          // Log entries
          if (widget.expanded)
            Expanded(
              child: logsAsync.when(
                data: (entries) => entries.isEmpty
                    ? Center(
                        child: Text(
                          'No activity yet',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: entries.length,
                        itemBuilder: (context, i) =>
                            _LogRow(entry: entries[i]),
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.accent),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final path = await ConnectionService.exportLogsCsv(
          connId: _filterConnId, eventType: _filterType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to $path'),
            backgroundColor: AppTheme.card,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}

class _PanelHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final AsyncValue<Map<String, dynamic>> statsAsync;
  final VoidCallback onExport;
  final bool exporting;
  final LogEventType? filterType;
  final void Function(LogEventType?) onFilterType;

  const _PanelHeader({
    required this.expanded,
    required this.onToggle,
    required this.statsAsync,
    required this.onExport,
    required this.exporting,
    required this.filterType,
    required this.onFilterType,
  });

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.value ?? {};
    final speedBytes = (stats['speed'] as num?)?.toInt() ?? 0;
    final speedLabel = _formatSpeed(speedBytes);
    final transferring =
        (stats['transferring'] as List<dynamic>?)?.length ?? 0;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Activity Log',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontSize: 12),
            ),
            const SizedBox(width: 16),
            if (transferring > 0) ...[
              const Icon(Icons.sync, size: 12, color: AppTheme.accent),
              const SizedBox(width: 4),
              Text(
                '$transferring active',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
            ],
            if (speedBytes > 0) ...[
              const Icon(Icons.arrow_downward,
                  size: 11, color: AppTheme.success),
              const SizedBox(width: 3),
              Text(
                speedLabel,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.success),
              ),
            ],
            const Spacer(),
            // Filter chips
            if (expanded) ...[
              _FilterChip(
                label: 'Mount',
                selected: filterType == LogEventType.mount,
                onTap: () => onFilterType(
                    filterType == LogEventType.mount ? null : LogEventType.mount),
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: 'Transfer',
                selected: filterType == LogEventType.upload ||
                    filterType == LogEventType.download,
                onTap: () => onFilterType(
                    filterType == LogEventType.upload ? null : LogEventType.upload),
              ),
              const SizedBox(width: 4),
              _FilterChip(
                label: 'Error',
                selected: filterType == LogEventType.error,
                color: AppTheme.error,
                onTap: () => onFilterType(
                    filterType == LogEventType.error ? null : LogEventType.error),
              ),
              const SizedBox(width: 8),
              if (exporting)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.accent),
                )
              else
                InkWell(
                  onTap: onExport,
                  borderRadius: BorderRadius.circular(4),
                  child: const Icon(Icons.file_download,
                      size: 16, color: AppTheme.textSecondary),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSpeed(int bps) {
    if (bps > 1024 * 1024) return '${(bps / 1024 / 1024).toStringAsFixed(1)} MB/s';
    if (bps > 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    return '$bps B/s';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? color : AppTheme.textSecondary,
                fontSize: 11,
              ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final ActivityLogEntry entry;

  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(entry.eventType);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          SizedBox(
            width: 60,
            child: Text(
              _formatTime(entry.timestamp),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.textTertiary, fontSize: 10.5),
            ),
          ),

          // Event dot
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 4, right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),

          // Connection name
          SizedBox(
            width: 100,
            child: Text(
              entry.connName,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Message
          Expanded(
            child: Text(
              entry.message,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.textPrimary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Speed
          if (entry.speedLabel.isNotEmpty)
            Text(
              entry.speedLabel,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.success, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Color _eventColor(LogEventType type) {
    return switch (type) {
      LogEventType.mount => AppTheme.success,
      LogEventType.unmount => AppTheme.textSecondary,
      LogEventType.upload => AppTheme.accent,
      LogEventType.download => AppTheme.accentLight,
      LogEventType.delete => AppTheme.error,
      LogEventType.error => AppTheme.error,
      LogEventType.info => AppTheme.textTertiary,
    };
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
