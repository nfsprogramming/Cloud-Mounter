import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/connection_service.dart';
import '../services/windows_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _Header(),
          Expanded(
            child: settingsAsync.when(
              data: (settings) => SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      title: 'General',
                      children: [
                        _SettingToggle(
                          icon: Icons.launch,
                          label: 'Launch at startup',
                          subtitle: 'Start CloudMounter when you log in',
                          value: settings['launch_at_startup'] == 'true',
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .set('launch_at_startup', v.toString()),
                        ),
                        _SettingToggle(
                          icon: Icons.cloud_sync,
                          label: 'Auto-mount on launch',
                          subtitle: 'Mount connections with auto-mount enabled on startup',
                          value: settings['auto_mount_on_launch'] == 'true',
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .set('auto_mount_on_launch', v.toString()),
                        ),
                        _SettingAction(
                          icon: Icons.shortcut,
                          label: 'Create Desktop Shortcut',
                          subtitle: 'Add a shortcut to your desktop for quick access',
                          onPressed: () => WindowsService.createDesktopShortcut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Network',
                      children: [
                        _SettingSlider(
                          icon: Icons.arrow_upward,
                          label: 'Upload limit',
                          subtitle: 'Maximum upload speed in MB/s (0 = unlimited)',
                          value: double.tryParse(
                                  settings['upload_limit_mbps'] ?? '0') ??
                              0,
                          max: 100,
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .set('upload_limit_mbps', v.toInt().toString()),
                        ),
                        _SettingSlider(
                          icon: Icons.arrow_downward,
                          label: 'Download limit',
                          subtitle: 'Maximum download speed in MB/s (0 = unlimited)',
                          value: double.tryParse(
                                  settings['download_limit_mbps'] ?? '0') ??
                              0,
                          max: 100,
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .set('download_limit_mbps', v.toInt().toString()),
                        ),
                        _SettingToggle(
                          icon: Icons.router,
                          label: 'Use proxy',
                          subtitle: 'Route rclone traffic through a proxy server',
                          value: settings['proxy_enabled'] == 'true',
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .set('proxy_enabled', v.toString()),
                        ),
                        if (settings['proxy_enabled'] == 'true')
                          _ProxyFields(settings: settings, ref: ref),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Notifications',
                      children: [
                        _SettingToggle(
                          icon: Icons.cloud_done,
                          label: 'Mount / Unmount events',
                          subtitle: 'Notify when a drive is mounted or unmounted',
                          value: settings['notify_mount'] == 'true',
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .set('notify_mount', v.toString()),
                        ),
                        _SettingToggle(
                          icon: Icons.swap_vert,
                          label: 'Transfer complete',
                          subtitle: 'Notify when a file transfer finishes',
                          value: settings['notify_transfer'] == 'true',
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .set('notify_transfer', v.toString()),
                        ),
                        _SettingToggle(
                          icon: Icons.error_outline,
                          label: 'Errors only',
                          subtitle: 'Only show notifications for errors',
                          value: settings['notify_error'] == 'true',
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .set('notify_error', v.toString()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Maintenance',
                      children: [
                        _SettingAction(
                          icon: Icons.eject,
                          label: 'Force Unmount All',
                          subtitle: 'Instantly clear all active rclone mounts',
                          onPressed: () async {
                            await ConnectionService.unmountAll(
                                ref.read(connectionsProvider).value ?? []);
                            ref.read(connectionsProvider.notifier).refresh();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'About',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/icons/app_icon.png',
                                  width: 64,
                                  height: 64,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text('CloudMounter',
                                  style: Theme.of(context).textTheme.titleMedium),
                              Text('Built by NFS Programmer',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        const Divider(color: AppTheme.border),
                        _InfoRow(label: 'Version', value: '1.0.0'),
                        _InfoRow(label: 'Mount engine', value: 'rclone'),
                        _InfoRow(
                            label: 'Storage',
                            value: 'SQLite + System Keychain'),
                      ],
                    ),
                  ],
                ),
              ),
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            color: AppTheme.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Text('Settings', style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                )),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: children.indexed
                .map((e) => Column(children: [
                      e.$2,
                      if (e.$1 < children.length - 1)
                        const Divider(
                            height: 1, thickness: 1, color: AppTheme.border),
                    ]))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _SettingToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final double value;
  final double max;
  final void Function(double) onChanged;

  const _SettingSlider({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Text(
                value == 0 ? 'Unlimited' : '${value.toInt()} MB/s',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.accent),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: max,
            divisions: 20,
            activeColor: AppTheme.accent,
            inactiveColor: AppTheme.border,
            onChanged: onChanged,
          ),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ProxyFields extends StatefulWidget {
  final Map<String, String> settings;
  final WidgetRef ref;

  const _ProxyFields({required this.settings, required this.ref});

  @override
  State<_ProxyFields> createState() => _ProxyFieldsState();
}

class _ProxyFieldsState extends State<_ProxyFields> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.settings['proxy_host'] ?? '');
    _portCtrl = TextEditingController(text: widget.settings['proxy_port'] ?? '8080');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _hostCtrl,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: const InputDecoration(labelText: 'Proxy Host'),
              onChanged: (v) => widget.ref.read(settingsProvider.notifier).set('proxy_host', v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _portCtrl,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
              onChanged: (v) => widget.ref.read(settingsProvider.notifier).set('proxy_port', v),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _SettingAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  const _SettingAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
