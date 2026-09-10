import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_model.dart';
import '../providers/app_providers.dart';
import '../services/rclone_service.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_icon.dart';

class AddConnectionScreen extends ConsumerStatefulWidget {
  const AddConnectionScreen({super.key});

  @override
  ConsumerState<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

class _AddConnectionScreenState extends ConsumerState<AddConnectionScreen> {
  int _step = 0;
  ConnectionType? _selectedType;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _autoMount = false;
  bool _isEncrypted = false;
  String _encryptionPassword = '';
  bool _isSaving = false;
  String _onedriveType = 'personal';

  // Per-type field controllers
  final Map<String, TextEditingController> _fields = {};
  bool _passiveMode = true;

  TextEditingController _field(String key) =>
      _fields.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _WizardHeader(step: _step, onBack: _step > 0 ? _prevStep : null),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: _buildStep(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _StepSelectType(
          selected: _selectedType,
          onSelect: (t) => setState(() => _selectedType = t),
          onNext: _selectedType != null ? _nextStep : null,
        ),
      1 => _StepConfigure(
          type: _selectedType!,
          nameCtrl: _nameCtrl,
          field: _field,
          passiveMode: _passiveMode,
          onPassiveToggle: (v) => setState(() => _passiveMode = v),
          onedriveType: _onedriveType,
          onOnedriveTypeChange: (v) => setState(() => _onedriveType = v),
          formKey: _formKey,
          onNext: _nextStep,
        ),
      2 => _StepMountOptions(
          autoMount: _autoMount,
          isEncrypted: _isEncrypted,
          onAutoMount: (v) => setState(() => _autoMount = v),
          onEncrypted: (v) => setState(() => _isEncrypted = v),
          onPasswordChange: (v) => _encryptionPassword = v,
          onSave: _save,
          isSaving: _isSaving,
        ),
      _ => const SizedBox(),
    };
  }

  void _nextStep() {
    if (_step == 1 && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _step++);
  }

  void _prevStep() => setState(() => _step--);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final config = _buildConfig();
      Map<String, dynamic> creds = _buildCredentials();

      if (_selectedType == ConnectionType.gdrive ||
          _selectedType == ConnectionType.dropbox ||
          _selectedType == ConnectionType.onedrive) {
        final sanitizedName = _nameCtrl.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.\+@ ]'), '_');
        final resultStr = await RcloneService.startOAuthConfig(
            sanitizedName, _selectedType!, config);
        if (resultStr != null && resultStr.isNotEmpty) {
          final result = jsonDecode(resultStr) as Map<String, dynamic>;
          creds['token'] = result['token'];
          if (result['drive_id'] != null) {
            config['drive_id'] = result['drive_id'];
          }
          if (result['drive_type'] != null) {
            config['drive_type'] = result['drive_type'];
          }
          debugPrint('[AddConnection] Extracted config from rclone dump: $config');
        } else {
          throw Exception('OAuth authentication failed or was cancelled.');
        }
      }

      await ref.read(connectionsProvider.notifier).addConnection(
            name: _nameCtrl.text.trim(),
            type: _selectedType!,
            config: config,
            credentials: creds,
            autoMount: _autoMount,
            isEncrypted: _isEncrypted,
            encryptionPassword: _isEncrypted ? _encryptionPassword : null,
          );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _buildConfig() {
    return switch (_selectedType!) {
      ConnectionType.onedrive => {
          'drive_type': _onedriveType,
        },
      ConnectionType.mega => {
          'username': _field('username').text,
        },
      _ => {},
    };
  }

  Map<String, dynamic> _buildCredentials() {
    return switch (_selectedType!) {
      ConnectionType.mega => {
          'password': _field('password').text,
        },
      _ => {},
    };
  }
}

// ─── Step 0: Select Type ─────────────────────────────────────────────────────

class _StepSelectType extends StatelessWidget {
  final ConnectionType? selected;
  final void Function(ConnectionType) onSelect;
  final VoidCallback? onNext;

  const _StepSelectType(
      {required this.selected, required this.onSelect, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a service', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Select the type of cloud storage or server to connect.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: ConnectionType.values.length,
              itemBuilder: (context, i) {
                final type = ConnectionType.values[i];
                final isSelected = selected == type;
                return _TypeCard(
                  type: type,
                  isSelected: isSelected,
                  onTap: () => onSelect(type),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onNext,
                child: const Text('Next →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatefulWidget {
  final ConnectionType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard(
      {required this.type, required this.isSelected, required this.onTap});

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.accent.withValues(alpha: 0.1)
                : _hovered
                    ? AppTheme.cardHover
                    : AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.accent
                  : _hovered
                      ? AppTheme.border
                      : AppTheme.border,
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProviderIcon(type: widget.type, size: 44),
              const SizedBox(height: 10),
              Text(
                widget.type.displayName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: widget.isSelected
                          ? AppTheme.accentLight
                          : AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 1: Configure ───────────────────────────────────────────────────────

class _StepConfigure extends StatelessWidget {
  final ConnectionType type;
  final TextEditingController nameCtrl;
  final TextEditingController Function(String) field;
  final bool passiveMode;
  final void Function(bool) onPassiveToggle;
  final String onedriveType;
  final void Function(String) onOnedriveTypeChange;
  final GlobalKey<FormState> formKey;
  final VoidCallback onNext;

  const _StepConfigure({
    required this.type,
    required this.nameCtrl,
    required this.field,
    required this.passiveMode,
    required this.onPassiveToggle,
    required this.onedriveType,
    required this.onOnedriveTypeChange,
    required this.formKey,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configure ${type.displayName}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Enter the connection details below.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),
          Expanded(
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildField(context, nameCtrl, 'Connection Name',
                        hint: 'My Google Drive', required: true),
                    const SizedBox(height: 16),
                    ..._buildTypeFields(context),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: onNext, child: const Text('Next →')),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTypeFields(BuildContext context) {
    switch (type) {
      case ConnectionType.gdrive:
      case ConnectionType.dropbox:
      case ConnectionType.onedrive:
        return [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.open_in_browser,
                    color: AppTheme.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OAuth Authentication',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(
                          'A browser window will open to authorize access after saving.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: onedriveType,
            decoration: const InputDecoration(labelText: 'OneDrive Account Type'),
            items: const [
              DropdownMenuItem(value: 'personal', child: Text('Personal')),
              DropdownMenuItem(value: 'business', child: Text('Business / School')),
              DropdownMenuItem(value: 'sharepoint', child: Text('SharePoint')),
            ],
            onChanged: (v) => onOnedriveTypeChange(v!),
          ),
        ];
      case ConnectionType.mega:
        return [
          _buildField(context, field('username'), 'Email Address', required: true),
          const SizedBox(height: 12),
          _buildField(context, field('password'), 'Password',
              obscure: true, required: true),
        ];

    }
  }

  Widget _buildField(
    BuildContext context,
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool obscure = false,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (label == 'Connection Name') {
                final regex = RegExp(r'^[a-zA-Z0-9_\.\+@ ]+$');
                if (!regex.hasMatch(v.trim())) {
                  return 'Invalid characters (use a-z, 0-9, _, -, ., +, @)';
                }
              }
              return null;
            }
          : null,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _SwitchRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

// ─── Step 2: Mount Options ───────────────────────────────────────────────────

class _StepMountOptions extends StatefulWidget {
  final bool autoMount;
  final bool isEncrypted;
  final void Function(bool) onAutoMount;
  final void Function(bool) onEncrypted;
  final void Function(String) onPasswordChange;
  final Future<void> Function() onSave;
  final bool isSaving;

  const _StepMountOptions({
    required this.autoMount,
    required this.isEncrypted,
    required this.onAutoMount,
    required this.onEncrypted,
    required this.onPasswordChange,
    required this.onSave,
    required this.isSaving,
  });

  @override
  State<_StepMountOptions> createState() => _StepMountOptionsState();
}

class _StepMountOptionsState extends State<_StepMountOptions> {
  final _encPassCtrl = TextEditingController();

  @override
  void dispose() {
    _encPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mount Options', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Configure how this connection behaves.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),
          Expanded(
            child: Column(
              children: [
                _OptionCard(
                  icon: Icons.play_arrow_rounded,
                  title: 'Auto-mount on launch',
                  subtitle: 'Automatically mount this connection when the app starts.',
                  trailing: Switch(
                      value: widget.autoMount,
                      onChanged: widget.onAutoMount),
                ),
                const SizedBox(height: 12),
                _OptionCard(
                  icon: Icons.lock_outline,
                  title: 'Enable AES-256 encryption',
                  subtitle:
                      'Encrypts all files before upload via rclone crypt. Requires a password.',
                  trailing: Switch(
                      value: widget.isEncrypted,
                      onChanged: widget.onEncrypted),
                ),
                if (widget.isEncrypted) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _encPassCtrl,
                    obscureText: true,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Encryption Password',
                      hintText: 'Stored securely in system keychain',
                    ),
                    onChanged: widget.onPasswordChange,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: ElevatedButton(
                  onPressed: widget.isSaving ? null : widget.onSave,
                  child: widget.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Connection'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ─── Wizard Header ───────────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;

  const _WizardHeader({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    const labels = ['Select Type', 'Configure', 'Options'];
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              color: AppTheme.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 18),
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 20,
              height: 20,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text('Add Connection',
              style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          Row(
            children: List.generate(labels.length, (i) {
              final active = i == step;
              final done = i < step;
              return Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppTheme.success
                          : active
                              ? AppTheme.accent
                              : AppTheme.surface,
                      border: Border.all(
                        color: done
                            ? AppTheme.success
                            : active
                                ? AppTheme.accent
                                : AppTheme.border,
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check,
                              size: 12, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: active
                                    ? Colors.white
                                    : AppTheme.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  if (i < labels.length - 1)
                    Container(
                      width: 32,
                      height: 1,
                      color: done ? AppTheme.success : AppTheme.border,
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
