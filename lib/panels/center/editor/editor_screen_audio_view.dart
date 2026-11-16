import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/audio_clip.dart';
import 'package:fide/models/audio_edit.dart';
import 'package:fide/models/clock_time.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/audio_effects.dart';
import 'package:fide/services/audio_file_service.dart';
import 'package:fide/services/audio_playback.dart';
import 'package:fide/widgets/audio_waveform.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_slider.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/file_facts_label.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/viewer_toolbar.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Edits a sound file without leaving FIDE: plays and stops it, trims it
/// by dragging the handles on its waveform, changes its speed without
/// changing its pitch and its pitch without changing its speed, then saves
/// it over the file in the file's own format.
///
/// Play plays the sound as edited, the playhead following on the
/// original's waveform.
class EditorScreenAudioView extends ConsumerStatefulWidget {
  /// Creates the audio editor of [filePath].
  const EditorScreenAudioView({super.key, required this.filePath});

  /// The sound edited.
  final String filePath;

  @override
  ConsumerState<EditorScreenAudioView> createState() =>
      _EditorScreenAudioViewState();
}

class _EditorScreenAudioViewState extends ConsumerState<EditorScreenAudioView>
    with SingleTickerProviderStateMixin {
  /// Hertz in a kilohertz.
  static const int _hertzPerKilohertz = 1000;

  /// Ways the pitch shifts: down and up.
  static const int _directions = 2;

  /// Channels of a stereo sound.
  static const int _stereoChannels = 2;

  /// The sound loaded, or null while it loads or when it can't be.
  LoadedAudio? _audio;

  /// Whether the edited sound is being made or saved.
  bool _busy = false;

  /// The changes made to the sound.
  AudioEdit _edit = AudioEdit.none;

  /// Why the sound couldn't be loaded, or null.
  Object? _error;

  /// Counts plays, so a play ending after another started leaves it be.
  int _playCount = 0;

  /// Time the sound has played, for the playhead.
  final Stopwatch _played = Stopwatch();

  /// Plays the sound.
  late final AudioPlayback _playback;

  /// Share of the original sound playing, or null when stopped.
  final ValueNotifier<double?> _playhead = ValueNotifier(null);

  /// Whether the sound is playing, or starting to.
  bool _playing = false;

  /// The edit the sound playing was made with.
  AudioEdit _playingEdit = AudioEdit.none;

  /// The sound made with [_renderedEdit], kept to play or save again.
  AudioClip? _rendered;

  /// The edit [_rendered] was made with.
  AudioEdit? _renderedEdit;

  /// Moves the playhead every frame while the sound plays.
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _playback = AudioPlayback(
      ref.read(desktopShellProvider),
      ref.read(audioFileServiceProvider),
    );
    _ticker = createTicker((_) => _movePlayhead());
    unawaited(_load());
  }

  @override
  void didUpdateWidget(EditorScreenAudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _stop();
      _audio = null;
      _error = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _playhead.dispose();
    unawaited(_playback.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return EmptyState.error(
        title: "Can't open this sound",
        message: _describe(error),
      );
    }
    final audio = _audio;
    if (audio == null) return const LoadingIndicator();
    final clip = audio.clip;
    final edit = _edit;
    final canEdit = !_busy;
    final hasChanges = canEdit && !edit.isNone;
    return Column(
      children: [
        ViewerToolbar(
          leading: [
            CompactIconButton(
              key: const Key('keyAudioPlay'),
              icon: _playing ? Icons.stop : Icons.play_arrow,
              tooltip: _playing ? 'Stop' : 'Play',
              onPressed: _playing || canEdit ? _togglePlay : null,
            ),
            Text(
              edit.lengthOf(clip.duration).clockLabel,
              style: AppTextStyle.monospace,
            ),
            if (_busy) const InlineSpinner(size: AppIconSize.medium),
          ],
          trailing: [
            FileFactsLabel(
              key: ObjectKey(audio),
              filePath: widget.filePath,
              facts: [_sampleRateLabel(clip), _channelsLabel(clip)],
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: AppPadding.panelContent,
            child: AudioWaveform(
              peaks: audio.peaks,
              start: edit.start,
              end: edit.end,
              playhead: _playhead,
              onTrimmed: (start, end) {
                if (canEdit) _change(edit.copyWith(start: start, end: end));
              },
            ),
          ),
        ),
        HeaderBar(
          isFooter: true,
          child: Wrap(
            spacing: AppSpacing.xLarge,
            runSpacing: AppSpacing.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildLabel(
                'Trim',
                '${(clip.duration * edit.start).clockLabel}'
                    ' – ${(clip.duration * edit.end).clockLabel}',
              ),
              _buildLabel(
                'Speed',
                '${(edit.tempo * AppMetric.percent).round()}%',
                CompactSlider(
                  value: edit.tempo * AppMetric.percent,
                  min: EditorConfig.audioMinTempoPercent.toDouble(),
                  max: EditorConfig.audioMaxTempoPercent.toDouble(),
                  divisions:
                      (EditorConfig.audioMaxTempoPercent -
                          EditorConfig.audioMinTempoPercent) ~/
                      EditorConfig.audioTempoStepPercent,
                  onChanged: canEdit
                      ? (percent) => _change(
                          edit.copyWith(
                            tempo: percent.round() / AppMetric.percent,
                          ),
                        )
                      : null,
                ),
              ),
              _buildLabel(
                'Pitch',
                '${edit.semitones > 0 ? '+' : ''}${edit.semitones} st',
                CompactSlider(
                  value: edit.semitones.toDouble(),
                  min: -EditorConfig.audioMaxSemitones.toDouble(),
                  max: EditorConfig.audioMaxSemitones.toDouble(),
                  // One step per semitone, down and up
                  divisions: EditorConfig.audioMaxSemitones * _directions,
                  onChanged: canEdit
                      ? (semitones) =>
                            _change(edit.copyWith(semitones: semitones.round()))
                      : null,
                ),
              ),
              CompactTextButton(
                icon: Icons.restart_alt,
                label: 'Reset',
                tooltip: 'Undo every change not saved',
                onPressed: hasChanges ? () => _change(AudioEdit.none) : null,
              ),
              CompactTextButton(
                icon: Icons.download,
                label: 'Save',
                tooltip: 'Write the changes over the file',
                onPressed: hasChanges ? _save : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A footer control: [title], then [control] when given, then its
  /// [value].
  Widget _buildLabel(String title, String value, [Widget? control]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.small,
      children: [
        Text(title, style: AppTextStyle.secondary(context)),
        ?control,
        Text(value, style: AppTextStyle.monospace),
      ],
    );
  }

  /// Replaces the edit with [edit], stopping the sound playing.
  void _change(AudioEdit edit) {
    if (edit == _edit) return;
    _stop();
    setState(() => _edit = edit);
  }

  /// "Mono", "Stereo" or the number of channels of [clip].
  static String _channelsLabel(AudioClip clip) =>
      switch (clip.channels.length) {
        1 => 'Mono',
        _stereoChannels => 'Stereo',
        final count => '$count channels',
      };

  /// What went wrong, for people to read.
  static String _describe(Object error) => switch (error) {
    ProcessException(:final message) => message,
    FormatException(:final message) => message,
    FileSystemException(:final message, :final path) => '$message: $path',
    _ => '$error',
  };

  /// Loads [EditorScreenAudioView.filePath], dropping the edit once
  /// loaded; the sound shown, if any, stays until then.
  Future<void> _load() async {
    final path = widget.filePath;
    try {
      final audio = await ref
          .read(audioFileServiceProvider)
          .load(path, peakCount: EditorConfig.audioPeakCount);
      if (!mounted || path != widget.filePath) return;
      setState(() {
        _audio = audio;
        _edit = AudioEdit.none;
        _rendered = null;
        _renderedEdit = null;
      });
    } catch (error) {
      if (mounted && path == widget.filePath) setState(() => _error = error);
    }
  }

  /// Puts the playhead where the sound playing is on the original.
  void _movePlayhead() {
    final audio = _audio;
    if (audio == null) return;
    _playhead.value = _playingEdit.sourceShareAt(
      _played.elapsed,
      audio.clip.duration,
    );
  }

  /// The sound as edited, made off the UI isolate once per edit.
  Future<AudioClip> _render(AudioClip clip) async {
    final edit = _edit;
    final rendered = _rendered;
    if (edit.isNone) return clip;
    if (rendered != null && _renderedEdit == edit) return rendered;
    final made = await Isolate.run(() => AudioEffects.apply(clip, edit));
    if (edit == _edit) {
      _rendered = made;
      _renderedEdit = edit;
    }
    return made;
  }

  /// Saves the edited sound over the file, then reloads it.
  Future<void> _save() async {
    final audio = _audio;
    if (audio == null) return;
    _stop();
    setState(() => _busy = true);
    final path = widget.filePath;
    try {
      final clip = await _render(audio.clip);
      await ref.read(audioFileServiceProvider).save(clip, path);
      if (!mounted) return;
      MessageBox.showSuccess(context, 'Saved ${p.basename(path)}');
      await _load();
    } catch (error) {
      if (mounted) {
        MessageBox.showError(context, "Couldn't save: ${_describe(error)}");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "44.1 kHz": [clip]'s sample rate in kilohertz.
  static String _sampleRateLabel(AudioClip clip) {
    final kilohertz = clip.sampleRate / _hertzPerKilohertz;
    final text = kilohertz == kilohertz.roundToDouble()
        ? '${kilohertz.round()}'
        : '$kilohertz';
    return '$text kHz';
  }

  /// Stops the sound playing and its playhead.
  void _stop() {
    _playCount++;
    _playback.stop();
    _stopped();
  }

  /// Shows the sound stopped.
  void _stopped() {
    _ticker.stop();
    _played
      ..stop()
      ..reset();
    _playhead.value = null;
    if (mounted && _playing) setState(() => _playing = false);
  }

  /// Plays the edited sound, or stops it when it plays.
  Future<void> _togglePlay() async {
    final audio = _audio;
    if (_playing || audio == null) return _stop();
    final play = ++_playCount;
    final edit = _edit;
    setState(() {
      _playing = true;
      _busy = true;
    });
    try {
      final clip = await _render(audio.clip);
      if (play != _playCount) return;
      setState(() => _busy = false);
      await _playback.play(
        clip,
        onStarted: () {
          _playingEdit = edit;
          _played.start();
          _ticker.start();
        },
      );
    } catch (error) {
      if (mounted) {
        MessageBox.showError(context, "Couldn't play: ${_describe(error)}");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      if (play == _playCount) _stopped();
    }
  }
}
