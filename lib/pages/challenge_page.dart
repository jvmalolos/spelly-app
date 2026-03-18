import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as gml;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart' as sig;

class ChallengePage extends StatefulWidget {
  const ChallengePage({super.key});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage> {
  static const String _wordsKey = 'spelling_words';
  static const String _historyKey = 'challenge_history';
  static const String _languageCode = 'en-US';
  static const int _challengeDuration = 120;

  final FlutterTts _tts = FlutterTts();
  late final gml.DigitalInkRecognizer _recognizer =
      gml.DigitalInkRecognizer(languageCode: _languageCode);
  final gml.DigitalInkRecognizerModelManager _modelManager =
      gml.DigitalInkRecognizerModelManager();

  final sig.SignatureController _signatureController = sig.SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Timer? _timer;

  List<String> _words = <String>[];
  Size _writingArea = const Size(600, 300);

  int _currentIndex = 0;
  int _score = 0;
  int _timeLeft = _challengeDuration;

  bool _isLoading = true;
  bool _isFinished = false;
  bool _isModelReady = false;
  bool _isChecking = false;
  bool _checkedCurrentWord = false;

  String _feedbackMessage = 'Handwrite the word, then tap Check Spelling.';
  String _recognizedText = '';
  String _modelStatus = 'Preparing handwriting model...';

  @override
  void initState() {
    super.initState();
    _setLandscapeMode();
    _configureTts();
    _prepareChallenge();
  }

  Future<void> _setLandscapeMode() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
  }

  Future<void> _prepareChallenge() async {
    try {
      await _loadWords();
      await _ensureHandwritingModel();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      if (_words.isNotEmpty) {
        _startTimer();
        await _playCurrentWord();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _feedbackMessage = 'Could not start challenge: $error';
        _modelStatus = 'Model unavailable';
      });
    }
  }

  Future<void> _loadWords() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWords = prefs.getStringList(_wordsKey) ?? <String>[];

    _words = savedWords
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
  }

  Future<void> _showResultDialog({
    required bool isCorrect,
    required String recognizedText,
    required String correctWord,
  }) async {
    final isLastWord = _currentIndex >= _words.length - 1;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isCorrect ? 'Correct' : 'Incorrect'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ML Kit read: "$recognizedText"'),
            const SizedBox(height: 8),
            Text('Correct spelling: "$correctWord"'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();

              if (isLastWord) {
                await _finishChallenge();
              } else {
                await _nextWord();
              }
            },
            child: Text(isLastWord ? 'Finish' : 'Next Word'),
          ),
        ],
      ),
    );
  }



  Future<void> _ensureHandwritingModel() async {
    if (mounted) {
      setState(() {
        _modelStatus = 'Checking handwriting model...';
      });
    }

    final isDownloaded =
        await _modelManager.isModelDownloaded(_languageCode);

    if (!isDownloaded) {
      if (mounted) {
        setState(() {
          _modelStatus = 'Downloading handwriting model...';
        });
      }

      final didDownload = await _modelManager.downloadModel(
        _languageCode,
        isWifiRequired: false,
      );

      if (!didDownload) {
        throw Exception(
          'ML Kit could not download the en-US handwriting model.',
        );
      }
    }

    _isModelReady = true;

    if (mounted) {
      setState(() {
        _modelStatus = 'ML Kit ready';
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isFinished) {
        timer.cancel();
        return;
      }

      if (_timeLeft <= 1) {
        timer.cancel();
        _finishChallenge(autoFinished: true);
        return;
      }

      setState(() {
        _timeLeft--;
      });
    });
  }

  Future<void> _playCurrentWord() async {
    if (_words.isEmpty || _isFinished) {
      return;
    }

    await _tts.stop();
    await _tts.speak(_words[_currentIndex]);
  }

  Future<void> _checkSpelling() async {
    if (_words.isEmpty || _isFinished || _isChecking) {
      return;
    }

    if (_checkedCurrentWord) {
      setState(() {
        _feedbackMessage = 'This word has already been checked.';
      });
      return;
    }

    if (!_isModelReady) {
      setState(() {
        _feedbackMessage = 'Handwriting model is not ready yet.';
      });
      return;
    }

    if (_signatureController.isEmpty) {
      setState(() {
        _feedbackMessage = 'Write the word first before checking.';
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _recognizedText = '';
      _feedbackMessage = 'Checking handwriting...';
    });

    try {
      final ink = _buildInkFromSignature();
      final context = gml.DigitalInkRecognitionContext(
        writingArea: gml.WritingArea(
          width: _writingArea.width,
          height: _writingArea.height,
        ),
      );

      final candidates = await _recognizer.recognize(ink, context: context);

      if (!mounted) {
        return;
      }

      final recognizedCandidates = candidates
          .map((candidate) => candidate.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (recognizedCandidates.isEmpty) {
        setState(() {
          _isChecking = false;
          _feedbackMessage =
              'I could not read that clearly. Try writing larger and more neatly.';
        });
        return;
      }

      final expected = _normalizeWord(_words[_currentIndex]);
      final matchedText = recognizedCandidates.firstWhere(
        (candidate) => _normalizeWord(candidate) == expected,
        orElse: () => recognizedCandidates.first,
      );

      final isCorrect = _normalizeWord(matchedText) == expected;

      setState(() {
        _isChecking = false;
        _checkedCurrentWord = true;
        _recognizedText = matchedText;

        if (isCorrect) {
          _score++;
          _feedbackMessage = 'Correct. ML Kit read "$matchedText".';
        } else {
          _feedbackMessage =
              'Incorrect. ML Kit read "$matchedText". Correct spelling: ${_words[_currentIndex]}';
        }
      });

      await _showResultDialog(
        isCorrect: isCorrect,
        recognizedText: matchedText,
        correctWord: _words[_currentIndex],
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isChecking = false;
        _feedbackMessage = 'Recognition failed: $error';
      });
    }
  }


  gml.Ink _buildInkFromSignature() {
    final ink = gml.Ink();
    final signatureStrokes = _signatureController.pointsToStrokes(2.0);
    var timestamp = DateTime.now().millisecondsSinceEpoch;

    for (final signatureStroke in signatureStrokes) {
      final stroke = gml.Stroke();

      for (final point in signatureStroke) {
        stroke.points.add(
          gml.StrokePoint(
            x: point.offset.dx,
            y: point.offset.dy,
            t: timestamp,
          ),
        );
        timestamp += 16;
      }

      if (stroke.points.isNotEmpty) {
        ink.strokes.add(stroke);
      }
    }

    return ink;
  }

  String _normalizeWord(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  }

  Future<void> _nextWord() async {
    if (_words.isEmpty || _isFinished) {
      return;
    }

    if (!_checkedCurrentWord) {
      setState(() {
        _feedbackMessage = 'Check the current word first before moving on.';
      });
      return;
    }

    if (_currentIndex >= _words.length - 1) {
      await _finishChallenge();
      return;
    }

    setState(() {
      _currentIndex++;
      _checkedCurrentWord = false;
      _recognizedText = '';
      _feedbackMessage = 'New word ready. Tap Play Word to hear it again.';
      _signatureController.clear();
    });

    await _playCurrentWord();
  }

  void _clearInput() {
    _signatureController.clear();

    setState(() {
      _recognizedText = '';
      _feedbackMessage = 'Canvas cleared.';
    });
  }

  Future<void> _finishChallenge({bool autoFinished = false}) async {
    if (_isFinished) {
      return;
    }

    _isFinished = true;
    _timer?.cancel();
    await _tts.stop();

    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? <String>[];

    final attempt = <String, dynamic>{
      'date': DateTime.now().toIso8601String(),
      'score': _score,
      'total': _words.length,
      'words': _words,
      'completedWords': _currentIndex + (_checkedCurrentWord ? 1 : 0),
      'timeUsed': _challengeDuration - _timeLeft,
      'autoFinished': autoFinished,
    };

    history.insert(0, jsonEncode(attempt));
    await prefs.setStringList(_historyKey, history);

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Challenge Finished'),
        content: Text(
          'Score: $_score / ${_words.length}\n'
          'Time used: ${_challengeDuration - _timeLeft} seconds',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    _recognizer.close();
    _signatureController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_modelStatus),
            ],
          ),
        ),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Challenge')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No spelling words saved yet',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Go to Spelling Set and save your words first.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/spelling-set');
                    },
                    child: const Text('Open Spelling Set'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final currentWordNumber = _currentIndex + 1;
    final progress = currentWordNumber / _words.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Challenge',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Word $currentWordNumber of ${_words.length}',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _InfoCard(
                    width: 170,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Time Left', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(_timeLeft),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _timeLeft <= 20
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _InfoCard(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Score', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          '$_score / ${_words.length}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.gesture_rounded,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Handwriting Area',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isModelReady
                                          ? theme.colorScheme.primaryContainer
                                          : theme.colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(_modelStatus),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final nextSize = Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );

                                  if (_writingArea != nextSize) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (!mounted) {
                                        return;
                                      }
                                      setState(() {
                                        _writingArea = nextSize;
                                      });
                                    });
                                  }

                                  return ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(24),
                                    ),
                                    child: sig.Signature(
                                      controller: _signatureController,
                                      backgroundColor: theme.colorScheme.surface,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Check Spelling',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(_feedbackMessage),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      _recognizedText.isEmpty
                                          ? 'Recognized text will appear here.'
                                          : 'Recognized: $_recognizedText',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Tip: Write one word only, large and clearly.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _playCurrentWord,
                                      icon: const Icon(Icons.volume_up_rounded),
                                      label: const Text('Play Word'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _isChecking ? null : _checkSpelling,
                                      icon: _isChecking
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.spellcheck_rounded),
                                      label: Text(
                                        _isChecking
                                            ? 'Checking...'
                                            : 'Check Spelling',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _nextWord,
                                      icon: const Icon(Icons.skip_next_rounded),
                                      label: const Text('Next Word'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _clearInput,
                                      icon: const Icon(Icons.cleaning_services_rounded),
                                      label: const Text('Clear'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _finishChallenge,
                                  icon: const Icon(Icons.flag_rounded),
                                  label: const Text('Finish'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
    this.width,
  });

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: child,
    );
  }
}
