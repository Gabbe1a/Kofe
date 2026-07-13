import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';

class AuthPhoneScreen extends ConsumerStatefulWidget {
  const AuthPhoneScreen({super.key});
  @override
  ConsumerState<AuthPhoneScreen> createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends ConsumerState<AuthPhoneScreen> {
  final _phone = TextEditingController(text: '9883429900');
  String _channel = 'sms';
  @override
  void dispose() { _phone.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Вход в профиль', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 10),
            Text('Введите телефон, чтобы копить бонусы и оформлять заказы.', style: TextStyle(color: palette.inkMuted)),
            const SizedBox(height: 28),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixText: '+7 ', hintText: '(999) 000-00-00'),
            ),
            const SizedBox(height: 22),
            const Text('Получить код', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ChannelChip(label: 'SMS', selected: _channel == 'sms', onTap: () => setState(() => _channel = 'sms')),
              _ChannelChip(label: 'Telegram', icon: Icons.send_rounded, selected: _channel == 'telegram', onTap: () => setState(() => _channel = 'telegram')),
              _ChannelChip(label: 'Звонок', icon: Icons.phone_in_talk_outlined, selected: _channel == 'call', onTap: () => setState(() => _channel = 'call')),
            ]),
            const Spacer(),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _phone.text.length < 10 ? null : () => context.push('/auth/code'), child: const Text('Получить код'))),
            const SizedBox(height: 12),
            Text('Продолжая, вы принимаете пользовательское соглашение и политику конфиденциальности.', textAlign: TextAlign.center, style: TextStyle(color: palette.inkMuted, fontSize: 11, height: 1.35)),
          ]),
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Material(
      color: selected ? palette.ink : palette.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 15, color: selected ? palette.canvas : palette.ink), const SizedBox(width: 5)], Text(label, style: TextStyle(color: selected ? palette.canvas : palette.ink, fontWeight: FontWeight.w800, fontSize: 13))]),
        ),
      ),
    );
  }
}

class AuthCodeScreen extends ConsumerStatefulWidget {
  const AuthCodeScreen({super.key});
  @override
  ConsumerState<AuthCodeScreen> createState() => _AuthCodeScreenState();
}

class _AuthCodeScreenState extends ConsumerState<AuthCodeScreen> {
  final _focus = FocusNode();
  final _code = TextEditingController();
  int _seconds = 59;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && _seconds > 0) setState(() => _seconds--); });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }
  @override
  void dispose() { _timer?.cancel(); _focus.dispose(); _code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final code = _code.text;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Подтверждение', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 10),
            Text('Мы отправили код на номер +7 (988) 342-99-00', style: TextStyle(color: palette.inkMuted)),
            const SizedBox(height: 28),
            Stack(children: [
              Row(children: List.generate(4, (index) {
                final active = index == code.length || code.length == 4 && index == 3;
                final filled = index < code.length;
                return Expanded(
                  child: Container(
                    height: 68,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? palette.ink : palette.line, width: active ? 1.5 : 1)),
                    child: Text(filled ? code[index] : '·', style: TextStyle(color: filled ? palette.ink : palette.inkMuted, fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                );
              })),
              Opacity(opacity: .01, child: TextField(focusNode: _focus, controller: _code, keyboardType: TextInputType.number, maxLength: 4, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(counterText: ''), onChanged: (_) => setState(() {}))),
            ]),
            const SizedBox(height: 18),
            Center(child: Text(_seconds > 0 ? 'Отправить повторно через 00:${_seconds.toString().padLeft(2, '0')}' : 'Отправить код повторно', style: TextStyle(color: palette.inkMuted, fontWeight: FontWeight.w700))),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: code.length != 4 ? null : () async {
                  final user = await ref.read(apiProvider).fetchMe();
                  ref.read(sessionProvider.notifier).login(user);
                  if (context.mounted) context.go('/profile');
                },
                child: const Text('Подтвердить'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
