import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpellingSetPage extends StatefulWidget {
  const SpellingSetPage({super.key});

  @override
  State<SpellingSetPage> createState() => _SpellingSetPageState();
}

class _SpellingSetPageState extends State<SpellingSetPage> {
  static const String _storageKey = 'spelling_words';

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(10, (_) => TextEditingController());
    _focusNodes = List.generate(10, (_) => FocusNode());
    _loadWords();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWords() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWords = prefs.getStringList(_storageKey) ?? <String>[];

    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].text = i < savedWords.length ? savedWords[i] : '';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveWords() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final words = _controllers.map((controller) => controller.text.trim()).toList();

    await prefs.setStringList(_storageKey, words);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Spelling set saved.'),
      ),
    );
  }

  Future<void> _clearWords() async {
    for (final controller in _controllers) {
      controller.clear();
    }
    await _saveWords();
  }

  int _filledCount() {
    return _controllers.where((controller) => controller.text.trim().isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filledCount = _filledCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spelling Set'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set your 10 spelling words',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can change these anytime. The Challenge page will use the saved list.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _InfoChip(
                              label: '$filledCount / 10 filled',
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            const SizedBox(width: 12),
                            const _InfoChip(
                              label: 'Editable anytime',
                              icon: Icons.edit_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < _controllers.length; i++) ...[
                    _WordFieldCard(
                      index: i,
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      onSubmitted: (_) {
                        if (i < _focusNodes.length - 1) {
                          _focusNodes[i + 1].requestFocus();
                        } else {
                          FocusScope.of(context).unfocus();
                        }
                        setState(() {});
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveWords,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Words'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _clearWords,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear All'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tip: Try to keep each entry to one English word for smoother challenge rounds.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _WordFieldCard extends StatelessWidget {
  const _WordFieldCard({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onChanged,
  });

  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Text('${index + 1}'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: index == 9 ? TextInputAction.done : TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                hintText: 'Enter word ${index + 1}',
                border: InputBorder.none,
              ),
              onSubmitted: onSubmitted,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
