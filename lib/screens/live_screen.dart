import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, this.initial});

  final LiveChannel? initial;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  String? _categoryId;
  LiveChannel? _selected;
  List<EpgProgram> _epg = [];
  bool _loadingEpg = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    if (_selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEpg(_selected!));
    }
  }

  Future<void> _loadEpg(LiveChannel channel) async {
    setState(() {
      _selected = channel;
      _loadingEpg = true;
    });
    final programs = await context.read<AppState>().epgFor(channel);
    if (!mounted) return;
    setState(() {
      _epg = programs;
      _loadingEpg = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = state.liveCategories;
    final channels = state.liveByCategory(_categoryId);
    final wide = MediaQuery.sizeOf(context).width >= 980;

    final sidebar = _CategoryRail(
      categories: categories,
      selectedId: _categoryId,
      onSelect: (id) => setState(() => _categoryId = id),
    );

    final list = _ChannelList(
      channels: channels,
      selected: _selected,
      onSelect: _loadEpg,
      onPlay: (channel) => openPlayback(
        context,
        PlaybackRequest(
          title: channel.name,
          kind: MediaKind.live,
          streamId: channel.streamId,
          posterUrl: channel.logoUrl,
          extension: 'm3u8',
        ),
      ),
    );

    final epg = _EpgPanel(
      channel: _selected,
      programs: _epg,
      loading: _loadingEpg,
      onPlay: _selected == null
          ? null
          : () => openPlayback(
                context,
                PlaybackRequest(
                  title: _selected!.name,
                  kind: MediaKind.live,
                  streamId: _selected!.streamId,
                  posterUrl: _selected!.logoUrl,
                  extension: 'm3u8',
                ),
              ),
    );

    if (!wide) {
      return Column(
        children: [
          SizedBox(height: 56, child: sidebar),
          Expanded(child: list),
          SizedBox(height: 168, child: epg),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: 240, child: sidebar),
        const VerticalDivider(width: 1),
        Expanded(flex: 3, child: list),
        const VerticalDivider(width: 1),
        SizedBox(width: 340, child: epg),
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [const Category(id: '', name: 'Todos', kind: MediaKind.live), ...categories];
    final vertical = MediaQuery.sizeOf(context).width >= 980;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item.id.isEmpty ? null : item.id;
        final selected = selectedId == id;
        return Padding(
          padding: const EdgeInsets.all(4),
          child: ChoiceChip(
            label: Text(item.name),
            selected: selected,
            onSelected: (_) => onSelect(id),
            selectedColor: AppColors.accent,
            showCheckmark: false,
          ),
        );
      },
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.selected,
    required this.onSelect,
    required this.onPlay,
  });

  final List<LiveChannel> channels;
  final LiveChannel? selected;
  final ValueChanged<LiveChannel> onSelect;
  final ValueChanged<LiveChannel> onPlay;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const Center(child: Text('No hay canales en esta categoría.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final channel = channels[index];
        final on = selected?.streamId == channel.streamId;
        return ListTile(
          selected: on,
          selectedTileColor: AppColors.accent.withOpacity(0.12),
          leading: CircleAvatar(
            backgroundColor: AppColors.surfaceHigh,
            backgroundImage: channel.logoUrl != null
                ? CachedNetworkImageProvider(channel.logoUrl!)
                : null,
            child: channel.logoUrl == null
                ? Text(channel.name.isEmpty ? '?' : channel.name[0])
                : null,
          ),
          title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            channel.epgChannelId == null ? 'Sin guía' : 'EPG disponible',
            style: const TextStyle(color: AppColors.faint, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_fill, color: AppColors.accent),
            onPressed: () => onPlay(channel),
          ),
          onTap: () => onSelect(channel),
          onLongPress: () => onPlay(channel),
        );
      },
    );
  }
}

class _EpgPanel extends StatelessWidget {
  const _EpgPanel({
    required this.channel,
    required this.programs,
    required this.loading,
    required this.onPlay,
  });

  final LiveChannel? channel;
  final List<EpgProgram> programs;
  final bool loading;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hm();
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: channel == null
            ? const Center(
                child: Text(
                  'Selecciona un canal para ver la guía.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel!.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (onPlay != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Ver ahora'),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Programación',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (loading)
                    const LinearProgressIndicator(color: AppColors.accent)
                  else if (programs.isEmpty)
                    const Text(
                      'No hay EPG para este canal.',
                      style: TextStyle(color: AppColors.faint),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: programs.length,
                        itemBuilder: (context, index) {
                          final program = programs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${time.format(program.start.toLocal())} – ${time.format(program.end.toLocal())}',
                                  style: TextStyle(
                                    color: program.isNow
                                        ? AppColors.accent
                                        : AppColors.faint,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  program.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (program.isNow)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: LinearProgressIndicator(
                                      value: program.progress,
                                      color: AppColors.accent,
                                      backgroundColor: AppColors.outline,
                                      minHeight: 3,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
