import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

// Default avatar definitions: (icon, background color, foreground color)
const _defaultAvatars = [
  (icon: Icons.person,             bg: Color(0xFFE8607C), fg: Colors.white),
  (icon: Icons.face,               bg: Color(0xFF3B82F6), fg: Colors.white),
  (icon: Icons.sentiment_satisfied,bg: Color(0xFF8B5CF6), fg: Colors.white),
  (icon: Icons.local_hospital,     bg: Color(0xFFEF4444), fg: Colors.white),
  (icon: Icons.favorite,           bg: Color(0xFFEC4899), fg: Colors.white),
  (icon: Icons.star,               bg: Color(0xFFF59E0B), fg: Colors.white),
  (icon: Icons.self_improvement,   bg: Color(0xFF22C55E), fg: Colors.white),
  (icon: Icons.emoji_nature,       bg: Color(0xFF14B8A6), fg: Colors.white),
  (icon: Icons.sports_soccer,      bg: Color(0xFFF97316), fg: Colors.white),
  (icon: Icons.music_note,         bg: Color(0xFF6366F1), fg: Colors.white),
  (icon: Icons.pets,               bg: Color(0xFF84CC16), fg: Colors.white),
  (icon: Icons.flight,             bg: Color(0xFF0EA5E9), fg: Colors.white),
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _sex;
  String? _phone;
  String? _avatarType;
  int? _avatarIndex;
  Uint8List? _avatarImageBytes;
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      AuthService.getName(),
      AuthService.getSex(),
      AuthService.getPhone(),
    ]);
    final name = results[0];
    final sex = results[1];
    final phone = results[2];
    final avatar = await AuthService.getAvatarData();
    if (!mounted) return;
    _nameController.text = name ?? '';
    Uint8List? imageBytes;
    if (avatar['type'] == 'custom' && avatar['image'] != null) {
      imageBytes = base64Decode(avatar['image'] as String);
    }
    setState(() {
      _sex = sex;
      _phone = phone;
      _avatarType = avatar['type'] as String?;
      _avatarIndex = avatar['index'] as int?;
      _avatarImageBytes = imageBytes;
      _loading = false;
    });
  }

  Color get _accentColor =>
      _sex == 'Female' ? const Color(0xFFEC4899) : const Color(0xFFE8607C);

  LinearGradient get _headerGradient => _sex == 'Female'
      ? const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFFE8607C), Color(0xFFF4A0B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _avatarType = 'custom';
      _avatarIndex = null;
      _avatarImageBytes = bytes;
      _changed = true;
    });
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _avatarType = 'custom';
      _avatarIndex = null;
      _avatarImageBytes = bytes;
      _changed = true;
    });
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Upload Photo',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library_outlined,
                      color: _accentColor),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt_outlined,
                      color: _accentColor),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await AuthService.updateName(_nameController.text.trim());
    if (_sex != null) await AuthService.updateSex(_sex!);

    if (_avatarType == 'custom' && _avatarImageBytes != null) {
      if (_avatarImageBytes!.length > 500000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Image is too large. Please choose an image under 500 KB.'),
          ));
          setState(() => _saving = false);
        }
        return;
      }
      await AuthService.setCustomAvatar(base64Encode(_avatarImageBytes!));
    } else if (_avatarType == 'default' && _avatarIndex != null) {
      await AuthService.setDefaultAvatar(_avatarIndex!);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              onChanged: () => setState(() => _changed = true),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildNameSection(),
                  const SizedBox(height: 16),
                  _buildPhoneSection(),
                  const SizedBox(height: 16),
                  _buildSexSection(),
                  const SizedBox(height: 16),
                  _buildAvatarSection(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 15, color: _accentColor),
              const SizedBox(width: 8),
              Text(
                'MOBILE PHONE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.6),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 11, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Cannot be changed',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_outlined,
                    color: Colors.grey[400], size: 20),
                const SizedBox(width: 12),
                Text(
                  _phone?.isNotEmpty == true ? _phone! : 'Not provided',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _phone?.isNotEmpty == true
                        ? Colors.grey[700]
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSexSection() {
    const teal = Color(0xFFE8607C);
    const pink = Color(0xFFEC4899);
    final current = _sex ?? 'Male';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wc_outlined, size: 15, color: _accentColor),
              const SizedBox(width: 8),
              Text(
                'SEX',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ProfileSexChip(
                label: 'Male',
                icon: Icons.male,
                selected: current == 'Male',
                activeColor: teal,
                onTap: () => setState(() { _sex = 'Male'; _changed = true; }),
              ),
              const SizedBox(width: 12),
              _ProfileSexChip(
                label: 'Female',
                icon: Icons.female,
                selected: current == 'Female',
                activeColor: pink,
                onTap: () => setState(() { _sex = 'Female'; _changed = true; }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: _headerGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 24),
      child: Row(
        children: [
          Tooltip(
            message: 'Go back',
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Edit Profile',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 15, color: _accentColor),
              const SizedBox(width: 8),
              Text(
                'FULL NAME',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline, color: _accentColor),
              filled: true,
              fillColor: const Color(0xFFF8FFFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.face_outlined, size: 15, color: _accentColor),
              const SizedBox(width: 8),
              Text(
                'PROFILE AVATAR',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Current avatar preview + upload button
          Row(
            children: [
              _buildAvatarPreview(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _avatarType == 'custom'
                          ? 'Custom photo selected'
                          : _avatarType == 'default' && _avatarIndex != null
                              ? 'Default avatar #${(_avatarIndex! + 1)}'
                              : 'No avatar set',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Tooltip(
                      message: 'Upload a photo from gallery or camera',
                      child: OutlinedButton.icon(
                        onPressed: _showImageSourcePicker,
                        icon: const Icon(Icons.upload_outlined, size: 16),
                        label: const Text('Upload Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accentColor,
                          side: BorderSide(color: _accentColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Or choose a default avatar',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _defaultAvatars.length,
            itemBuilder: (ctx, i) {
              final a = _defaultAvatars[i];
              final isSelected =
                  _avatarType == 'default' && _avatarIndex == i;
              return Tooltip(
                message: 'Select avatar ${i + 1}',
                child: GestureDetector(
                  onTap: () => setState(() {
                    _avatarType = 'default';
                    _avatarIndex = i;
                    _avatarImageBytes = null;
                    _changed = true;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? _accentColor
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _accentColor.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      backgroundColor: a.bg,
                      child: Icon(a.icon, color: a.fg, size: 22),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview() {
    if (_avatarType == 'custom' && _avatarImageBytes != null) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: MemoryImage(_avatarImageBytes!),
      );
    }
    if (_avatarType == 'default' && _avatarIndex != null) {
      final a = _defaultAvatars[_avatarIndex!];
      return CircleAvatar(
        radius: 36,
        backgroundColor: a.bg,
        child: Icon(a.icon, color: a.fg, size: 32),
      );
    }
    return CircleAvatar(
      radius: 36,
      backgroundColor: _accentColor.withValues(alpha: 0.15),
      child: Icon(Icons.person_outline,
          color: _accentColor, size: 32),
    );
  }

  Widget _buildSaveButton() {
    return Tooltip(
      message: 'Save profile changes',
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _headerGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Profile',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _ProfileSexChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ProfileSexChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: 'Select $label',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(alpha: 0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? activeColor.withValues(alpha: 0.6)
                    : Colors.grey.shade200,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? activeColor : Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? activeColor : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
