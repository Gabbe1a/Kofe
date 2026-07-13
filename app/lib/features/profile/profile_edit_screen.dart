import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  DateTime? _birth;
  bool _filledFromApi = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _birth = user?.birthDate;
    _filledFromApi = user != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Данные сохранены (mock)')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    if (!_filledFromApi) {
      ref.listen(meProvider, (prev, next) {
        next.whenData((user) {
          if (_filledFromApi || !mounted) return;
          setState(() {
            _filledFromApi = true;
            _name.text = user.name;
            _phone.text = user.phone;
            _email.text = user.email ?? '';
            _birth = user.birthDate;
          });
        });
      });
    }

    final birthLabel = _birth == null
        ? 'Не указана'
        : DateFormat('dd.MM.yyyy').format(_birth!);

    InputDecoration fieldDecoration(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: palette.surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Мои данные'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        minimum: KofeLayout.pageSafeArea,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const SizedBox(height: 8),
            Column(
              children: [
                  TextField(
                    controller: _name,
                    decoration: fieldDecoration('Имя *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    decoration: fieldDecoration('Телефон'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    decoration: fieldDecoration('Email'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _birth ?? DateTime(2000, 1, 1),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _birth = picked);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: fieldDecoration('Дата рождения *'),
                      child: Row(
                        children: [
                          Expanded(child: Text(birthLabel)),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: palette.ink,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: ElevatedButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ),
    );
  }
}
