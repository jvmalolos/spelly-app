import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _profileNameKey = 'profile_name';
  static const String _themeKey = 'seasonal_theme';
  static const String _wordsKey = 'spelling_words';
  static const String _historyKey = 'challenge_history';

  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isApplyingTheme = false;
  String _selectedTheme = 'spring';

  final List<_ThemeOption> _themeOptions = const [
    _ThemeOption(
      value: 'spring',
      title: 'Spring',
      subtitle: 'Fresh greens and soft floral tones',
      color: Color(0xFF8CBF7F),
    ),
    _ThemeOption(
      value: 'summer',
      title: 'Summer',
      subtitle: 'Sunny sand, sea, and bright sky tones',
      color: Color(0xFFE6B85C),
    ),
    _ThemeOption(
      value: 'autumn',
      title: 'Autumn',
      subtitle: 'Warm leaves, spice, and earthy colors',
      color: Color(0xFFB96A3B),
    ),
    _ThemeOption(
      value: 'winter',
      title: 'Winter',
      subtitle: 'Cool air, snow, and crisp blue-gray tones',
      color: Color(0xFF6D8AA8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _nameController.text = prefs.getString(_profileNameKey) ?? '';
    _selectedTheme = prefs.getString(_themeKey) ?? 'spring';

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSavingProfile = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileNameKey, _nameController.text.trim());

    if (!mounted) {
      return;
    }

    await AppSession.of(context)?.refreshAppSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingProfile = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved.')),
    );
  }

  Future<void> _saveTheme() async {
    setState(() {
      _isApplyingTheme = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _selectedTheme);

    if (!mounted) {
      return;
    }

    await AppSession.of(context)?.refreshAppSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      _isApplyingTheme = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme applied.')),
    );
  }

  Future<void> _deleteAccount() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'This will remove your profile, spelling set, scoreboard history, and app preferences on this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileNameKey);
    await prefs.remove(_themeKey);
    await prefs.remove(_wordsKey);
    await prefs.remove(_historyKey);

    if (!mounted) {
      return;
    }

    await AppSession.of(context)?.refreshAppSettings();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set the name that personalizes your app.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          hintText: 'Enter your name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _isSavingProfile ? null : _saveProfile,
                        icon: _isSavingProfile
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSavingProfile ? 'Saving...' : 'Save Profile',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Color Theme',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a seasonal theme, then tap Save Theme to apply it across the app.',
                      ),
                      const SizedBox(height: 16),
                      for (final option in _themeOptions) ...[
                        _ThemeTile(
                          option: option,
                          isSelected: _selectedTheme == option.value,
                          onTap: () {
                            setState(() {
                              _selectedTheme = option.value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _isApplyingTheme ? null : _saveTheme,
                        icon: _isApplyingTheme
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(
                          _isApplyingTheme ? 'Applying...' : 'Save Theme',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This clears all local app data on this device and returns you to the Home page.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: _deleteAccount,
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: const Text('Delete Account'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _ThemeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? option.color.withAlpha(35)
              : theme.colorScheme.surfaceContainerHighest.withAlpha(70),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? option.color : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: option.color,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? option.color : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption {
  const _ThemeOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String value;
  final String title;
  final String subtitle;
  final Color color;
}

