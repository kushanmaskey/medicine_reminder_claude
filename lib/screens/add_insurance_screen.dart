import 'package:flutter/material.dart';
import '../models/insurance.dart';
import '../services/storage_service.dart';

const _gradient = LinearGradient(
  colors: [Color(0xFF501513), Color(0xFF7A2420)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class AddInsuranceScreen extends StatefulWidget {
  final Insurance? existing;
  const AddInsuranceScreen({super.key, this.existing});

  @override
  State<AddInsuranceScreen> createState() => _AddInsuranceScreenState();
}

class _AddInsuranceScreenState extends State<AddInsuranceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _provider;
  late final TextEditingController _plan;
  late final TextEditingController _memberId;
  late final TextEditingController _groupNumber;
  late final TextEditingController _phone;
  late final TextEditingController _copay;
  late final TextEditingController _deductible;
  late final TextEditingController _notes;

  DateTime? _effectiveDate;
  DateTime? _expirationDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _provider = TextEditingController(text: e?.providerName ?? '');
    _plan = TextEditingController(text: e?.planName ?? '');
    _memberId = TextEditingController(text: e?.memberId ?? '');
    _groupNumber = TextEditingController(text: e?.groupNumber ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _copay = TextEditingController(text: e?.copay ?? '');
    _deductible = TextEditingController(text: e?.deductible ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _effectiveDate = e?.effectiveDate;
    _expirationDate = e?.expirationDate;
  }

  @override
  void dispose() {
    _provider.dispose();
    _plan.dispose();
    _memberId.dispose();
    _groupNumber.dispose();
    _phone.dispose();
    _copay.dispose();
    _deductible.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isEffective}) async {
    final initial = isEffective
        ? (_effectiveDate ?? DateTime.now())
        : (_expirationDate ?? DateTime.now().add(const Duration(days: 365)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: const Color(0xFF501513)),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isEffective) {
        _effectiveDate = picked;
      } else {
        _expirationDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final insurance = Insurance(
        id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        providerName: _provider.text.trim(),
        planName: _plan.text.trim(),
        memberId: _memberId.text.trim(),
        groupNumber: _groupNumber.text.trim(),
        effectiveDate: _effectiveDate,
        expirationDate: _expirationDate,
        phone: _phone.text.trim(),
        copay: _copay.text.trim(),
        deductible: _deductible.text.trim(),
        notes: _notes.text.trim(),
      );
      if (widget.existing == null) {
        await StorageService.saveInsurance(insurance);
      } else {
        await StorageService.updateInsurance(insurance);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Insurance'),
        content: const Text('Are you sure you want to delete this insurance record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await StorageService.deleteInsurance(widget.existing!.id);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Not set';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        title: Text(
          isEdit ? 'Edit Insurance' : 'Add Insurance',
          style: const TextStyle(
            color: Color(0xFF484141),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF484141), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: const BoxDecoration(gradient: _gradient),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            _buildSection('Insurance Provider', [
              _buildField(_provider, 'Provider Name', required: true,
                  hint: 'e.g. Blue Cross Blue Shield'),
              const SizedBox(height: 12),
              _buildField(_plan, 'Plan Name', hint: 'e.g. Gold PPO'),
            ]),
            const SizedBox(height: 20),
            _buildSection('Member Information', [
              _buildField(_memberId, 'Member ID / Policy Number'),
              const SizedBox(height: 12),
              _buildField(_groupNumber, 'Group Number'),
            ]),
            const SizedBox(height: 20),
            _buildSection('Coverage Dates', [
              _buildDatePicker('Effective Date', _effectiveDate, isEffective: true),
              const SizedBox(height: 12),
              _buildDatePicker('Expiration Date', _expirationDate, isEffective: false),
            ]),
            const SizedBox(height: 20),
            _buildSection('Cost Information', [
              _buildField(_copay, 'Copay', hint: 'e.g. \$30'),
              const SizedBox(height: 12),
              _buildField(_deductible, 'Deductible', hint: 'e.g. \$1,500'),
            ]),
            const SizedBox(height: 20),
            _buildSection('Contact', [
              _buildField(_phone, 'Customer Service Phone',
                  hint: 'e.g. 1-800-123-4567',
                  keyboardType: TextInputType.phone),
            ]),
            const SizedBox(height: 20),
            _buildSection('Notes', [
              _buildField(_notes, 'Notes', maxLines: 3, hint: 'Additional information...'),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF501513).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEdit ? 'Save Changes' : 'Add Insurance',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF501513), width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, {required bool isEffective}) {
    return GestureDetector(
      onTap: () => _pickDate(isEffective: isEffective),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(
                    _fmtDate(value),
                    style: TextStyle(
                      fontSize: 14,
                      color: value == null ? Colors.grey[400] : const Color(0xFF1E293B),
                      fontWeight: value == null ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}
