import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/nexora_logo.dart';
import 'home_screen.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  final _scroll = ScrollController();
  bool _opaque = false;

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.movie_outlined, Icons.movie_rounded, 'Películas'),
    (Icons.video_library_outlined, Icons.video_library_rounded, 'Series'),
    (Icons.live_tv_outlined, Icons.live_tv_rounded, 'En vivo'),
    (Icons.search, Icons.search, 'Buscar'),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final next = _scroll.offset > 24;
      if (next != _opaque) setState(() => _opaque = next);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final pages = [
      HomeScreen(scrollController: _scroll),
      const MoviesScreen(),
      const SeriesScreen(),
      const LiveScreen(),
      const SearchScreen(),
      const SettingsScreen(),
    ];

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
      },
      child: Scaffold(
        body: Column(
          children: [
            _TopBar(
              index: _index,
              opaque: _opaque,
              wide: wide,
              onSelect: (value) => setState(() => _index = value),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: pages,
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index.clamp(0, 4),
                backgroundColor: AppColors.surface,
                indicatorColor: AppColors.accent.withOpacity(0.25),
                onDestinationSelected: (value) => setState(() => _index = value),
                destinations: [
                  for (final tab in _tabs)
                    NavigationDestination(
                      icon: Icon(tab.$1),
                      selectedIcon: Icon(tab.$2, color: AppColors.accent),
                      label: tab.$3,
                    ),
                ],
              ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.opaque,
    required this.wide,
    required this.onSelect,
  });

  final int index;
  final bool opaque;
  final bool wide;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 12, 8),
      decoration: BoxDecoration(
        color: opaque ? const Color(0xF20B0B0D) : const Color(0x990B0B0D),
        border: Border(
          bottom: BorderSide(
            color: opaque ? AppColors.outline : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => onSelect(0),
            child: const NexoraLogo(height: 32),
          ),
          if (wide) ...[
            const SizedBox(width: 28),
            for (var i = 0; i < ShellScreen._tabs.length; i++)
              _NavLink(
                label: ShellScreen._tabs[i].$3,
                selected: index == i,
                onTap: () => onSelect(i),
              ),
          ],
          const Spacer(),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => onSelect(5),
            icon: Icon(
              Icons.settings_outlined,
              color: index == 5 ? Colors.white : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : AppColors.muted,
          textStyle: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
