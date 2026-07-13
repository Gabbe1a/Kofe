import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data_providers.dart';
import '../../core/order_status.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfileFromApi());
  }

  Future<void> _refreshProfileFromApi() async {
    if (!ref.read(sessionProvider).isAuthed) return;
    try {
      final user = await ref.read(apiProvider).fetchMe();
      if (!mounted) return;
      ref.read(sessionProvider.notifier).updateUser(user);
    } catch (_) {
      // Keep cached session user offline.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final lastOrder = ordersAsync.maybeWhen(
      data: (orders) => orders.isEmpty ? null : orders.first,
      orElse: () => null,
    );
    final orderDateFmt = DateFormat('dd.MM, HH:mm');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        minimum: KofeLayout.pageSafeArea,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 120),
          children: [
            const _BrandRow(),
            const SizedBox(height: 22),
            if (session.isAuthed)
              _MemberCard(
                name: session.user!.name,
                phone: session.user!.phone,
                bonusBalance: session.user!.bonusBalance,
              )
            else
              _GuestCard(onLogin: () => context.push('/auth')),
            const SizedBox(height: 24),
            KofeSectionTitle(title: session.isAuthed ? 'Профиль' : 'Настройки'),
            const SizedBox(height: 10),
            if (session.isAuthed) ...[
              KofeSurface(
                padding: EdgeInsets.zero,
                color: AppColors.surface,
                child: Column(
                  children: [
                    _ProfileRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'История заказов',
                      onTap: () => context.push('/orders'),
                    ),
                    if (lastOrder != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.push('/orders/${lastOrder.id}'),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cream.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${orderDateFmt.format(lastOrder.createdAt)} · ${lastOrder.status.localized}',
                                        style: const TextStyle(
                                          color: AppColors.inkMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastOrder.summaryLine ?? 'Заказ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${lastOrder.total.toStringAsFixed(0)} ₽',
                                  style: const TextStyle(
                                    color: AppColors.forestDeep,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KofeSurface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.surface,
                child: Row(
                  children: [
                    const KofeRoundIcon(
                      icon: Icons.notifications_none_rounded,
                      color: AppColors.sageSoft,
                      iconColor: AppColors.forestDeep,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Уведомления',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: true,
                      activeThumbColor: AppColors.surface,
                      activeTrackColor: AppColors.forest,
                      onChanged: (_) => _openNotifications(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KofeSurface(
                padding: EdgeInsets.zero,
                color: AppColors.surface,
                child: Column(
                  children: [
                    _ProfileRow(
                      icon: Icons.brightness_6_outlined,
                      title: 'Тема оформления',
                      subtitle: _themeLabel(session.themePreference),
                      onTap: () => _showThemeSheet(context, ref),
                    ),
                    _ProfileRow(
                      icon: Icons.settings_outlined,
                      title: 'Настройки',
                      subtitle: 'Имя, телефон и дата рождения',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    _ProfileRow(
                      icon: Icons.info_outline_rounded,
                      title: 'О приложении',
                      subtitle: 'Кофе Мама, версия 1.0',
                      onTap: () => _showAbout(context),
                    ),
                    _ProfileRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Правовая информация',
                      subtitle: 'Политика и пользовательское соглашение',
                      showDivider: false,
                      onTap: () => _showStub(
                        context,
                        'Правовая информация будет открыта в приложении.',
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              KofeSurface(
                padding: EdgeInsets.zero,
                color: AppColors.creamWarm,
                child: Column(
                  children: [
                    _ProfileRow(
                      icon: Icons.brightness_6_outlined,
                      title: 'Тема оформления',
                      subtitle: _themeLabel(session.themePreference),
                      onTap: () => _showThemeSheet(context, ref),
                    ),
                    _ProfileRow(
                      icon: Icons.location_city_outlined,
                      title: 'Выбор города',
                      subtitle: session.city?.name ?? 'Выберите город',
                      onTap: () => context.push('/city'),
                    ),
                    _ProfileRow(
                      icon: Icons.info_outline_rounded,
                      title: 'О приложении',
                      subtitle: 'Кофе Мама, версия 1.0',
                      onTap: () => _showAbout(context),
                    ),
                    _ProfileRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Правовая информация',
                      subtitle: 'Политика и пользовательское соглашение',
                      onTap: () => _showStub(
                        context,
                        'Правовая информация будет открыта в приложении.',
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.bug_report_outlined,
                      title: 'Сообщить о проблеме',
                      subtitle: 'Мы передадим обращение команде',
                      showDivider: false,
                      onTap: () => _showStub(
                        context,
                        'Форма обратной связи будет доступна позже.',
                      ),
                    ),
                  ],
                ),
              ),
            if (session.isAuthed) ...[
              const SizedBox(height: 22),
              Center(
                child: TextButton(
                  onPressed: () => ref.read(sessionProvider.notifier).logout(),
                  child: const Text(
                    'Выйти',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Кофе Мама',
      applicationVersion: '1.0.0 mock',
      children: const [
        Text('Мобильное приложение для заказа кофе, десертов и бонусов.'),
      ],
    );
  }

  static String _themeLabel(ThemePreference preference) => switch (preference) {
    ThemePreference.system => 'Как в системе',
    ThemePreference.light => 'Светлая',
    ThemePreference.dark => 'Тёмная',
  };

  static Future<void> _showThemeSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final selected = ref.read(sessionProvider).themePreference;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тема оформления', style: Theme.of(sheetContext).textTheme.headlineMedium),
                const SizedBox(height: 14),
                ...ThemePreference.values.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_themeLabel(item)),
                  trailing: Icon(
                    selected == item ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  ),
                  onTap: () {
                    ref.read(sessionProvider.notifier).setThemePreference(item);
                    Navigator.pop(sheetContext);
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showStub(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _NotificationsScreen()),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.sageSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_cafe_rounded, color: AppColors.forest),
        ),
        const SizedBox(width: 12),
        const Text(
          'Кофе Мама',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return KofeSurface(
      color: AppColors.forest,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cream.withValues(alpha: 0.14),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.cream,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Гость',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Войдите, чтобы копить бонусы, видеть историю заказов и быстрее оплачивать кофе.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.cream.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cream,
                foregroundColor: AppColors.forest,
              ),
              onPressed: onLogin,
              child: const Text('Войти'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.name,
    required this.phone,
    required this.bonusBalance,
  });

  final String name;
  final String phone;
  final int bonusBalance;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();

    return KofeSurface(
      color: AppColors.forest,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(
                        color: AppColors.cream.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const KofeRoundIcon(
                  icon: Icons.stars_rounded,
                  color: AppColors.caramel,
                  iconColor: AppColors.forest,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$bonusBalance Бонусов',
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Оплачивайте до 50% заказа',
                        style: TextStyle(
                          color: AppColors.cream.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                KofeRoundIcon(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.inkMuted,
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 70),
      ],
    );
  }
}

class _NotificationsScreen extends ConsumerWidget {
  const _NotificationsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd.MM HH:mm');
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Уведомления')),
      body: SafeArea(
        top: false,
        minimum: KofeLayout.pageSafeArea,
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Ошибка загрузки\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return const Center(
                child: Text(
                  'Пока нет уведомлений',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return KofeSurface(
                  color: AppColors.creamWarm,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KofeRoundIcon(
                        icon: notification.type == 'order'
                            ? Icons.receipt_long_outlined
                            : Icons.campaign_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.body,
                              style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fmt.format(notification.createdAt),
                              style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
