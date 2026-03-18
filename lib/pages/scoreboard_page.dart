import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key});

  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  static const String _historyKey = 'challenge_history';

  bool _isLoading = true;
  List<Map<String, dynamic>> _attempts = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getStringList(_historyKey) ?? <String>[];

    final parsedAttempts = rawHistory
        .map((entry) {
          try {
            return jsonDecode(entry) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((entry) => entry.isNotEmpty)
        .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _attempts = parsedAttempts;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    final shouldClear = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear Scoreboard'),
            content: const Text(
              'This will remove all recorded challenge attempts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldClear) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _attempts = <Map<String, dynamic>>[];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scoreboard cleared.')),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      return 'Unknown date';
    }

    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) {
      return rawDate;
    }

    final local = parsed.toLocal();
    final month = _monthName(local.month);
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$month ${local.day}, ${local.year} • $hour:$minute $period';
  }

  String _monthName(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  String _formatWords(dynamic words) {
    if (words is! List) {
      return 'No words recorded';
    }

    final cleaned = words
        .map((word) => word.toString().trim())
        .where((word) => word.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      return 'No words recorded';
    }

    return cleaned.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoreboard'),
        actions: [
          if (_attempts.isNotEmpty)
            IconButton(
              onPressed: _clearHistory,
              tooltip: 'Clear scoreboard',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attempts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.leaderboard_rounded, size: 72),
                          const SizedBox(height: 16),
                          Text(
                            'No challenge attempts yet',
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Complete a challenge and your results will appear here.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAttempts,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withAlpha(120),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Progress',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_attempts.length} challenge attempt${_attempts.length == 1 ? '' : 's'} recorded',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var i = 0; i < _attempts.length; i++) ...[
                        _AttemptCard(
                          index: i,
                          attempt: _attempts[i],
                          formattedDate: _formatDate(_attempts[i]['date'] as String?),
                          formattedWords: _formatWords(_attempts[i]['words']),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({
    required this.index,
    required this.attempt,
    required this.formattedDate,
    required this.formattedWords,
  });

  final int index;
  final Map<String, dynamic> attempt;
  final String formattedDate;
  final String formattedWords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final score = attempt['score'] ?? 0;
    final total = attempt['total'] ?? 0;
    final completedWords = attempt['completedWords'] ?? 0;
    final timeUsed = attempt['timeUsed'] ?? 0;
    final autoFinished = attempt['autoFinished'] == true;

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formattedDate,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _scoreColor(theme, score, total).withAlpha(30),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$score / $total',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _scoreColor(theme, score, total),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(
                icon: Icons.spellcheck_rounded,
                label: 'Completed: $completedWords',
              ),
              _StatChip(
                icon: Icons.timer_outlined,
                label: 'Time: ${timeUsed}s',
              ),
              _StatChip(
                icon: autoFinished ? Icons.hourglass_bottom : Icons.flag_rounded,
                label: autoFinished ? 'Timed out' : 'Finished',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Word Set',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formattedWords,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(ThemeData theme, dynamic score, dynamic total) {
    final scoreValue = (score as num).toDouble();
    final totalValue = (total as num).toDouble();

    if (totalValue <= 0) {
      return theme.colorScheme.primary;
    }

    final ratio = scoreValue / totalValue;

    if (ratio >= 0.8) {
      return Colors.green.shade700;
    }
    if (ratio >= 0.5) {
      return Colors.orange.shade700;
    }
    return theme.colorScheme.error;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(130),
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
