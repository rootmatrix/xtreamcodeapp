import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final account = state.account;
    final expires = account?.expiresAt == null
        ? '—'
        : DateFormat.yMMMd().format(account!.expiresAt!.toLocal());

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 48),
      children: [
        const Text(
          'Ajustes',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        _Card(
          title: 'Cuenta',
          children: [
            _Row('Usuario', account?.username ?? '—'),
            _Row('Estado', account?.status ?? '—'),
            _Row('Caducidad', expires),
            _Row(
              'Conexiones',
              account?.maxConnections == null
                  ? '—'
                  : '${account!.activeConnections ?? 0} / ${account.maxConnections}',
            ),
            _Row('Servidor', state.xtream?.server ?? '—'),
          ],
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Aplicación',
          children: [
            const _Row('Versión', AppConstants.version),
            const _Row('Motor', 'Flutter · muxa_xtream'),
            _Row('Favoritos', '${state.favorites.length}'),
            _Row('Recientes', '${state.history.length}'),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await context.read<AppState>().clearLocalCache();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Caché local limpiada')),
              );
            }
          },
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Limpiar caché, favoritos y recientes'),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () async {
            await context.read<AppState>().logout();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Cambiar de cuenta'),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
