import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

import 'package:senzu_player/src/ui/widgets/senzu_style.dart';
import 'package:senzu_player/src/controllers/senzu_player_bundle.dart';
import 'package:senzu_player/src/controllers/senzu_ui_controller.dart';

class SenzuSidePanel extends StatefulWidget {
  const SenzuSidePanel({
    super.key,
    required this.bundle,
    required this.style,
    required this.panel,
    required this.child,
    this.width = 220,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;
  final SenzuPanel panel;
  final Widget child;
  final double width;

  @override
  State<SenzuSidePanel> createState() => _SenzuSidePanelState();
}

class _SenzuSidePanelState extends State<SenzuSidePanel> {
  final FocusNode _panelNode = FocusNode(debugLabel: 'senzu-panel-root');
  Worker? _panelWorker;

  bool get _visible => widget.bundle.ui.activePanel.value == widget.panel;

  String get title {
    switch (widget.panel) {
      case SenzuPanel.aspect:
        return widget.style.senzuLanguage.aspectRatio;
      case SenzuPanel.audio:
        return widget.style.senzuLanguage.audio;
      case SenzuPanel.caption:
        return widget.style.senzuLanguage.subtitles;
      case SenzuPanel.episode:
        return widget.style.senzuLanguage.episodes;
      case SenzuPanel.quality:
        return widget.style.senzuLanguage.quality;
      case SenzuPanel.settings:
        return widget.style.senzuLanguage.settings;
      case SenzuPanel.speed:
        return widget.style.senzuLanguage.playbackSpeed;
      case SenzuPanel.sleep:
        return widget.style.senzuLanguage.sleepTimer;
      case SenzuPanel.cast:
        return widget.style.senzuLanguage.cast;
      case SenzuPanel.none:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();

    _panelWorker = ever<SenzuPanel>(
      widget.bundle.ui.activePanel,
      (active) {
        if (active == widget.panel) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _panelNode.requestFocus();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _panelWorker?.dispose();
    _panelNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      widget.bundle.ui.activePanel.value = SenzuPanel.none;
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      FocusManager.instance.primaryFocus?.nextFocus();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      FocusManager.instance.primaryFocus?.previousFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final visible = _visible;

      return Align(
        alignment: Alignment.centerRight,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          offset: visible ? Offset.zero : const Offset(1.0, 0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: visible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !visible,
              child: ExcludeFocus(
                excluding: !visible,
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Focus(
                    focusNode: _panelNode,
                    onKeyEvent: _onKey,
                    child: Container(
                      width: widget.width,
                      padding: widget.style.settingsPanelStyle.panelPadding,
                      decoration:
                          widget.style.settingsPanelStyle.panelDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              top: 10,
                              bottom: 10,
                            ),
                            child: Text(
                              title,
                              style: widget.style.settingsPanelStyle.titleStyle,
                            ),
                          ),
                          Expanded(child: widget.child),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class SenzuQualityPanel extends StatelessWidget {
  const SenzuQualityPanel({
    super.key,
    required this.bundle,
    required this.style,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return SenzuSidePanel(
      bundle: bundle,
      style: style,
      panel: SenzuPanel.quality,
      child: Obx(() {
        final sources = bundle.core.rxSources.value ?? {};
        final active = bundle.core.rxActiveSource.value;

        return _PanelList(
          items: sources.keys.map((k) {
            return _PanelItemData(
              label: k,
              selected: k == active,
              onTap: k == active
                  ? null
                  : () {
                      final src = sources[k];
                      if (src != null) {
                        bundle.core.changeSource(name: k, source: src);
                        bundle.ui.activePanel.value = SenzuPanel.none;
                      }
                    },
            );
          }).toList(),
          style: style,
        );
      }),
    );
  }
}

class SenzuSpeedPanel extends StatelessWidget {
  const SenzuSpeedPanel({
    super.key,
    required this.bundle,
    required this.style,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return SenzuSidePanel(
      bundle: bundle,
      style: style,
      panel: SenzuPanel.speed,
      child: _SpeedContent(bundle: bundle, style: style),
    );
  }
}

class _SpeedContent extends StatefulWidget {
  const _SpeedContent({
    required this.bundle,
    required this.style,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  State<_SpeedContent> createState() => _SpeedContentState();
}

class _SpeedContentState extends State<_SpeedContent> {
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  final _currentSpeed = 1.0.obs;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();

    _currentSpeed.value = widget.bundle.core.playbackSpeed;

    _sub = widget.bundle.core.rxNativeState.listen((_) {
      _currentSpeed.value = widget.bundle.core.playbackSpeed;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cur = _currentSpeed.value;

      return _PanelList(
        style: widget.style,
        items: _speeds.map((s) {
          return _PanelItemData(
            label:
                s == 1.0 ? '1× (${widget.style.senzuLanguage.normal})' : '$s×',
            selected: (cur - s).abs() < 0.01,
            onTap: () async {
              await widget.bundle.core.setPlaybackSpeed(s);
              _currentSpeed.value = s;
              widget.bundle.ui.activePanel.value = SenzuPanel.none;
            },
          );
        }).toList(),
      );
    });
  }
}

class SenzuCaptionPanel extends StatelessWidget {
  const SenzuCaptionPanel({
    super.key,
    required this.bundle,
    required this.style,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return SenzuSidePanel(
      bundle: bundle,
      style: style,
      panel: SenzuPanel.caption,
      width: 240,
      child: Obx(() {
        final active = bundle.subtitle.activeCaption.value;
        final srcName = bundle.core.rxActiveSource.value;
        final subs = bundle.core.rxSources.value?[srcName]?.subtitle ?? {};

        return Column(
          children: [
            Expanded(
              child: _PanelList(
                style: style,
                items: [
                  _PanelItemData(
                    label: style.senzuLanguage.none,
                    selected: active == style.senzuLanguage.none,
                    onTap: () {
                      bundle.subtitle.changeSubtitle(
                        subtitle: null,
                        name: style.senzuLanguage.none,
                      );
                      bundle.ui.activePanel.value = SenzuPanel.none;
                    },
                  ),
                  ...subs.entries.map((e) {
                    return _PanelItemData(
                      label: e.key,
                      selected: active == e.key,
                      onTap: () {
                        bundle.subtitle.changeSubtitle(
                          subtitle: e.value,
                          name: e.key,
                        );
                        bundle.ui.activePanel.value = SenzuPanel.none;
                      },
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Obx(() {
                final size = bundle.subtitle.subtitleSize.value;

                return Column(
                  children: [
                    Text(
                      '${style.senzuLanguage.subtitleSize}: $size',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: style.progressBarStyle.color,
                        inactiveTrackColor:
                            style.progressBarStyle.backgroundColor,
                        thumbColor: style.progressBarStyle.dotColor,
                        overlayShape: SliderComponentShape.noOverlay,
                        trackHeight: style.progressBarStyle.height,
                      ),
                      child: Slider(
                        value: size.toDouble(),
                        min: 10,
                        max: 50,
                        divisions: 40,
                        onChanged: (v) {
                          bundle.subtitle.setSubtitleSize(v.toInt());
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        );
      }),
    );
  }
}

class SenzuAudioPanel extends StatelessWidget {
  const SenzuAudioPanel({
    super.key,
    required this.bundle,
    required this.style,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return SenzuSidePanel(
      bundle: bundle,
      style: style,
      panel: SenzuPanel.audio,
      child: Obx(() {
        return _PanelList(
          style: style,
          items: bundle.core.audioTracks.map((t) {
            return _PanelItemData(
              label: '${t.name} (${t.language})',
              selected: bundle.core.activeAudioTrack.value == t.id,
              onTap: () {
                bundle.core.setAudioTrack(t);
                bundle.ui.activePanel.value = SenzuPanel.none;
              },
            );
          }).toList(),
        );
      }),
    );
  }
}

class SenzuAspectPanel extends StatelessWidget {
  const SenzuAspectPanel({
    super.key,
    required this.bundle,
    required this.style,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    final aspects = <BoxFit, String>{
      BoxFit.cover: style.senzuLanguage.normal,
      BoxFit.contain: style.senzuLanguage.contain,
      BoxFit.fill: style.senzuLanguage.fill,
      BoxFit.fitWidth: style.senzuLanguage.fitWidth,
      BoxFit.fitHeight: style.senzuLanguage.fitHeight,
    };

    return SenzuSidePanel(
      bundle: bundle,
      style: style,
      panel: SenzuPanel.aspect,
      child: Obx(() {
        final current = bundle.ui.currentAspect.value;

        return _PanelList(
          style: style,
          items: aspects.entries.map((e) {
            return _PanelItemData(
              label: e.value,
              selected: current == e.key,
              onTap: () {
                bundle.ui.setAspect(e.key);
                bundle.ui.activePanel.value = SenzuPanel.none;
              },
            );
          }).toList(),
        );
      }),
    );
  }
}

class SenzuEpisodePanel extends StatelessWidget {
  const SenzuEpisodePanel({
    super.key,
    required this.bundle,
    required this.style,
  });

  final SenzuPlayerBundle bundle;
  final SenzuPlayerStyle style;

  @override
  Widget build(BuildContext context) {
    return SenzuSidePanel(
      bundle: bundle,
      style: style,
      panel: SenzuPanel.episode,
      width: 260,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: style.episodeWidget!,
      ),
    );
  }
}

class _PanelItemData {
  const _PanelItemData({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
}

class _PanelList extends StatefulWidget {
  const _PanelList({
    required this.items,
    required this.style,
  });

  final List<_PanelItemData> items;
  final SenzuPlayerStyle style;

  @override
  State<_PanelList> createState() => _PanelListState();
}

class _PanelListState extends State<_PanelList> {
  late List<FocusNode> _nodes;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _createNodes();
    _requestInitialFocus();
  }

  @override
  void didUpdateWidget(covariant _PanelList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.items.length != widget.items.length) {
      for (final node in _nodes) {
        node.dispose();
      }
      _createNodes();
      _requestInitialFocus();
    } else {
      _requestInitialFocus();
    }
  }

  void _createNodes() {
    _nodes = List.generate(
      widget.items.length,
      (i) => FocusNode(debugLabel: 'senzu-panel-item-$i'),
    );
  }

  void _requestInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _nodes.isEmpty) return;

      final selectedIndex = widget.items.indexWhere((e) => e.selected);
      final index = selectedIndex >= 0 ? selectedIndex : 0;

      _nodes[index].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;

    final offset = (index * 48.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];

        return FocusTraversalOrder(
          order: NumericFocusOrder(index.toDouble()),
          child: _PanelItem(
            focusNode: _nodes[index],
            style: widget.style,
            label: item.label,
            selected: item.selected,
            onTap: item.onTap,
            onFocused: () => _scrollToIndex(index),
          ),
        );
      },
    );
  }
}

class _PanelItem extends StatefulWidget {
  const _PanelItem({
    required this.focusNode,
    required this.label,
    required this.selected,
    required this.style,
    required this.onFocused,
    this.onTap,
  });

  final FocusNode focusNode;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final SenzuPlayerStyle style;
  final VoidCallback onFocused;

  @override
  State<_PanelItem> createState() => _PanelItemState();
}

class _PanelItemState extends State<_PanelItem> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onTap?.call();
      HapticFeedback.selectionClick();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;

    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: true,
      skipTraversal: false,
      onKeyEvent: _onKey,
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) widget.onFocused();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _focused
                ? Colors.white.withValues(alpha: 0.16)
                : widget.selected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled
                        ? Colors.white38
                        : widget.selected
                            ? widget.style.settingsPanelStyle.selectedTextColor
                            : widget
                                .style.settingsPanelStyle.unselectedTextColor,
                    fontSize: widget.style.settingsPanelStyle.selectedTextSize,
                    fontWeight:
                        widget.selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (widget.selected) widget.style.settingsPanelStyle.selectedIcon,
            ],
          ),
        ),
      ),
    );
  }
}
