import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _biographyController;
  late TextEditingController _countryController;
  late TextEditingController _ageController;
  String _maritalStatus = '';
  int? _birthdayDay;
  int? _birthdayMonth;
  int? _birthdayYear;
  String _presenceStatus = 'online';
  bool _privateMessagesOpen = true;
  bool _callsActive = true;
  String _gender = '';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(notificationSettingsProvider);
    _biographyController = TextEditingController(text: settings.biography);
    _countryController = TextEditingController(text: settings.country);
    _ageController = TextEditingController(text: settings.age?.toString() ?? '');
    _maritalStatus = settings.maritalStatus;
    _birthdayDay = settings.birthdayDay;
    _birthdayMonth = settings.birthdayMonth;
    _birthdayYear = settings.birthdayYear;
    _presenceStatus = settings.presenceStatus;
    _privateMessagesOpen = settings.privateMessagesOpen;
    _callsActive = settings.callsActive;
    _gender = settings.gender;
  }

  @override
  void dispose() {
    _biographyController.dispose();
    _countryController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final age = int.tryParse(_ageController.text);
    ref.read(notificationSettingsProvider.notifier).state =
        ref.read(notificationSettingsProvider).copyWith(
              biography: _biographyController.text,
              country: _countryController.text,
              age: age,
              maritalStatus: _maritalStatus,
              birthdayDay: _birthdayDay,
              birthdayMonth: _birthdayMonth,
              birthdayYear: _birthdayYear,
              presenceStatus: _presenceStatus,
              privateMessagesOpen: _privateMessagesOpen,
              callsActive: _callsActive,
              gender: _gender,
            );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil guardado'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: appTheme.background,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGenderSection(appTheme, settings),
          const SizedBox(height: 16),
          _buildSectionTitle('Información Personal', appTheme),
          const SizedBox(height: 8),
          _buildTextField(appTheme, 'Biografía (cuéntanos sobre ti...)', _biographyController, maxLines: 3),
          const SizedBox(height: 12),
          _buildTextField(appTheme, 'País', _countryController),
          const SizedBox(height: 12),
          _buildTextField(appTheme, 'Edad', _ageController, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _buildMaritalStatusDropdown(appTheme, settings),
          const SizedBox(height: 16),
          _buildSectionTitle('Cumpleaños', appTheme),
          const SizedBox(height: 8),
          _buildBirthdayPicker(appTheme, settings),
          const SizedBox(height: 16),
          _buildSectionTitle('Estado y Privacidad', appTheme),
          const SizedBox(height: 8),
          _buildPresenceStatusDropdown(appTheme, settings),
          const SizedBox(height: 12),
          _buildToggleTile(
            appTheme,
            icon: Icons.mail,
            iconColor: Colors.blue,
            title: 'Mensajes privados abiertos',
            subtitle: 'Permitir que otros te envíen mensajes privados',
            value: _privateMessagesOpen,
            onChanged: (v) => setState(() => _privateMessagesOpen = v),
          ),
          const SizedBox(height: 12),
          _buildToggleTile(
            appTheme,
            icon: Icons.videocam,
            iconColor: Colors.green,
            title: 'Llamadas activas',
            subtitle: 'Permitir llamadas de voz y video',
            value: _callsActive,
            onChanged: (v) => setState(() => _callsActive = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar perfil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppTheme appTheme) {
    return Text(
      title,
      style: TextStyle(
        color: appTheme.primary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildGenderSection(AppTheme appTheme, NotificationSettings settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Género',
            style: TextStyle(
              color: appTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona tu género para que aparezca junto a tu nick',
            style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGenderOption(appTheme, '♂️', 'Masculino', 'male'),
              const SizedBox(width: 12),
              _buildGenderOption(appTheme, '♀️', 'Femenino', 'female'),
              const SizedBox(width: 12),
              _buildGenderOption(appTheme, '⚧️', 'No binario', 'other'),
              const SizedBox(width: 12),
              _buildGenderOption(appTheme, '', 'No especificar', ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption(AppTheme appTheme, String emoji, String label, String value) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? appTheme.primary.withValues(alpha: 0.2) : appTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? appTheme.primary : appTheme.textSecondary.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? appTheme.primary : appTheme.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(AppTheme appTheme, String label, TextEditingController controller, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: appTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: appTheme.textSecondary),
        filled: true,
        fillColor: appTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: appTheme.textSecondary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: appTheme.textSecondary.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: appTheme.primary),
        ),
      ),
    );
  }

  Widget _buildMaritalStatusDropdown(AppTheme appTheme, NotificationSettings settings) {
    final options = ['', 'Soltero/a', 'En pareja', 'Casado/a', 'Divorciado/a', 'Viudo/a', 'Prefiero no decir'];
    return DropdownButtonFormField<String>(
      value: _maritalStatus.isEmpty ? '' : _maritalStatus,
      dropdownColor: appTheme.surface,
      style: TextStyle(color: appTheme.textPrimary),
      decoration: InputDecoration(
        labelText: 'Estado civil',
        labelStyle: TextStyle(color: appTheme.textSecondary),
        filled: true,
        fillColor: appTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: appTheme.textSecondary.withValues(alpha: 0.3)),
        ),
      ),
      items: options.map((e) => DropdownMenuItem(
        value: e,
        child: Text(e.isEmpty ? 'No especificar' : e),
      )).toList(),
      onChanged: (v) => setState(() => _maritalStatus = v ?? ''),
    );
  }

  Widget _buildBirthdayPicker(AppTheme appTheme, NotificationSettings settings) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _birthdayDay,
            dropdownColor: appTheme.surface,
            style: TextStyle(color: appTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Día',
              labelStyle: TextStyle(color: appTheme.textSecondary),
              filled: true,
              fillColor: appTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
            onChanged: (v) => setState(() => _birthdayDay = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _birthdayMonth,
            dropdownColor: appTheme.surface,
            style: TextStyle(color: appTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Mes',
              labelStyle: TextStyle(color: appTheme.textSecondary),
              filled: true,
              fillColor: appTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
            onChanged: (v) => setState(() => _birthdayMonth = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _birthdayYear,
            dropdownColor: appTheme.surface,
            style: TextStyle(color: appTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Año',
              labelStyle: TextStyle(color: appTheme.textSecondary),
              filled: true,
              fillColor: appTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: List.generate(80, (i) => DropdownMenuItem(value: 1946 + i, child: Text('${1946 + i}'))),
            onChanged: (v) => setState(() => _birthdayYear = v),
          ),
        ),
      ],
    );
  }

  Widget _buildPresenceStatusDropdown(AppTheme appTheme, NotificationSettings settings) {
    final options = {
      'online': ('Online', Colors.green),
      'absent': ('Ausente', Colors.orange),
      'dnd': ('No molestar', Colors.red),
    };
    return DropdownButtonFormField<String>(
      value: _presenceStatus,
      dropdownColor: appTheme.surface,
      style: TextStyle(color: appTheme.textPrimary),
      decoration: InputDecoration(
        labelText: 'Estado',
        labelStyle: TextStyle(color: appTheme.textSecondary),
        filled: true,
        fillColor: appTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: options.entries.map((e) => DropdownMenuItem(
        value: e.key,
        child: Row(
          children: [
            Icon(Icons.circle, size: 12, color: e.value.$2),
            const SizedBox(width: 8),
            Text(e.value.$1),
          ],
        ),
      )).toList(),
      onChanged: (v) => setState(() => _presenceStatus = v ?? 'online'),
    );
  }

  Widget _buildToggleTile(
    AppTheme appTheme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(color: appTheme.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: appTheme.textSecondary, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: iconColor,
      ),
    );
  }
}
