import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activity.dart';
import '../services/storage_service.dart';

const _activityTypes = [
  (type: 'Walk',      icon: Icons.directions_walk,  color: Color(0xFF22C55E)),
  (type: 'Run',       icon: Icons.directions_run,   color: Color(0xFFF97316)),
  (type: 'Exercise',  icon: Icons.fitness_center,   color: Color(0xFF3B82F6)),
  (type: 'Yoga',      icon: Icons.self_improvement, color: Color(0xFF8B5CF6)),
  (type: 'Meditation',icon: Icons.spa,              color: Color(0xFF0D9488)),
];

const _walkTypes = [
  (label: 'Regular', icon: Icons.directions_walk,   desc: 'Normal, comfortable pace'),
  (label: 'Brisk',   icon: Icons.directions_run,    desc: 'Fast-paced, elevated heart rate'),
];

class AddActivityScreen extends StatefulWidget {
  final Activity? existing;
  const AddActivityScreen({super.key, this.existing});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'Walk';
  String _walkType = 'Regular';
  DateTime _recordedAt = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  Color get _activeColor {
    return _activityTypes
        .firstWhere((t) => t.type == _type)
        .color;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _type = e.type;
      _walkType = e.walkType;
      _distanceController.text = e.distance?.toString() ?? '';
      _durationController.text = e.duration?.toString() ?? '';
      _notesController.text = e.notes;
      _recordedAt = e.recordedAt;
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isDistanceBased => _type == 'Walk' || _type == 'Run';

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: ColorScheme.light(primary: _activeColor)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    setState(() {
      _recordedAt = DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Remove this ${widget.existing!.type} activity?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.deleteActivity(widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final activity = Activity(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      walkType: _walkType,
      distance: double.tryParse(_distanceController.text.trim()),
      duration: double.tryParse(_durationController.text.trim()),
      recordedAt: _recordedAt,
      notes: _notesController.text.trim(),
    );

    if (_isEditing) {
      await StorageService.updateActivity(activity);
    } else {
      await StorageService.saveActivity(activity);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Activity' : 'Log Activity',
          style: const TextStyle(
              color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete activity',
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 16),
            if (_type == 'Walk') ...[
              _buildWalkTypeSection(),
              const SizedBox(height: 16),
            ],
            _buildDetailsSection(),
            const SizedBox(height: 16),
            _buildDateTimeSection(),
            const SizedBox(height: 16),
            _buildNotesSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ── Activity type selector ─────────────────────────────────────────────────

  Widget _buildTypeSelector() {
    return _SectionCard(
      title: 'Activity Type',
      icon: Icons.directions_run_outlined,
      iconColor: _activeColor,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _activityTypes.map((t) {
          final selected = _type == t.type;
          return Tooltip(
            message: 'Log a ${t.type} activity',
            child: GestureDetector(
              onTap: () => setState(() {
                _type = t.type;
                _distanceController.clear();
                _durationController.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? t.color.withValues(alpha: 0.12)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? t.color.withValues(alpha: 0.6)
                        : Colors.grey.shade200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon,
                        size: 18,
                        color: selected ? t.color : Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      t.type,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? t.color : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Walk type section ──────────────────────────────────────────────────────

  Widget _buildWalkTypeSection() {
    return _SectionCard(
      title: 'Walk Type',
      icon: Icons.directions_walk,
      iconColor: const Color(0xFF22C55E),
      child: Column(
        children: _walkTypes.map((wt) {
          final selected = _walkType == wt.label;
          return Tooltip(
            message: '${wt.label}: ${wt.desc}',
            child: InkWell(
              onTap: () => setState(() => _walkType = wt.label),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF22C55E).withValues(alpha: 0.10)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                        : Colors.grey.shade200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: wt.label,
                      groupValue: _walkType,
                      activeColor: const Color(0xFF22C55E),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _walkType = v!),
                    ),
                    const SizedBox(width: 6),
                    Icon(wt.icon,
                        size: 20,
                        color: selected
                            ? const Color(0xFF22C55E)
                            : Colors.grey[500]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wt.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            wt.desc,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Distance / Duration section ────────────────────────────────────────────

  Widget _buildDetailsSection() {
    if (_isDistanceBased) {
      return _SectionCard(
        title: 'Distance',
        icon: Icons.straighten,
        iconColor: _activeColor,
        child: Tooltip(
          message: 'Enter the distance covered in miles',
          child: TextFormField(
            controller: _distanceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: _inputDecoration('Distance', 'miles', _activeColor),
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) {
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Enter a valid distance';
              }
              return null;
            },
          ),
        ),
      );
    }

    final durationLabel = _type == 'Meditation'
        ? 'Meditation Duration'
        : _type == 'Yoga'
            ? 'Yoga Duration'
            : 'Exercise Duration';

    return _SectionCard(
      title: 'Duration',
      icon: Icons.timer_outlined,
      iconColor: _activeColor,
      child: Tooltip(
        message: 'Enter how long you did $_type in minutes',
        child: TextFormField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration(durationLabel, 'min', _activeColor),
          validator: (v) {
            if (v != null && v.trim().isNotEmpty) {
              final n = int.tryParse(v.trim());
              if (n == null || n <= 0) return 'Enter a valid duration';
            }
            return null;
          },
        ),
      ),
    );
  }

  // ── Date & time section ────────────────────────────────────────────────────

  Widget _buildDateTimeSection() {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel =
        '${months[_recordedAt.month - 1]} ${_recordedAt.day}, ${_recordedAt.year}';

    return _SectionCard(
      title: 'Date',
      icon: Icons.calendar_today_outlined,
      iconColor: _activeColor,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: _activeColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B)),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notes section ──────────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return _SectionCard(
      title: 'Notes',
      icon: Icons.notes_outlined,
      child: Tooltip(
        message: 'Add any notes about this activity (optional)',
        child: TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: _inputDecoration(
              'e.g. route, how you felt, location…', '', _activeColor),
        ),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Tooltip(
      message: _isEditing ? 'Save changes to this activity' : 'Save this activity log',
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _activeColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _isEditing ? 'Update Activity' : 'Save Activity',
                  style: const TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      String label, String suffix, Color color) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix.isNotEmpty ? suffix : null,
      filled: true,
      fillColor: Colors.white,
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
        borderSide: BorderSide(color: color),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}

// ── Shared section card ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor = const Color(0xFF0D9488),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
