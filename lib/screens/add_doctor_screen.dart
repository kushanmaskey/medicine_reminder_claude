import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/doctor.dart';
import '../services/storage_service.dart';

class AddDoctorScreen extends StatefulWidget {
  final Doctor? existing;
  const AddDoctorScreen({super.key, this.existing});

  @override
  State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController  = TextEditingController();
  final _lastNameController   = TextEditingController();
  final _credentialController = TextEditingController();
  final _specialtyController  = TextEditingController();
  final _phoneController      = TextEditingController();
  final _addressController    = TextEditingController();
  final _cityController       = TextEditingController();
  final _zipController        = TextEditingController();
  final _npiController        = TextEditingController();
  final _notesController      = TextEditingController();

  String? _selectedState;
  String? _searchSelectedState;

  // NPI search controllers
  final _searchFirstController = TextEditingController();
  final _searchLastController  = TextEditingController();

  bool _saving = false;
  bool _searchExpanded = false;
  bool _searching = false;
  String? _searchError;
  List<_NpiResult> _searchResults = [];

  bool get _isEditing => widget.existing != null;
  static const _accent = Color(0xFF0EA5E9);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _firstNameController.text  = e.firstName;
      _lastNameController.text   = e.lastName;
      _credentialController.text = e.credential;
      _specialtyController.text  = e.specialty;
      _phoneController.text      = e.phone;
      _addressController.text    = e.address;
      _cityController.text       = e.city;
      _selectedState             = e.state.isNotEmpty ? e.state : null;
      _zipController.text        = e.zip;
      _npiController.text        = e.npiNumber;
      _notesController.text      = e.notes;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _credentialController.dispose();
    _specialtyController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _npiController.dispose();
    _notesController.dispose();
    _searchFirstController.dispose();
    _searchLastController.dispose();
    super.dispose();
  }

  void _dismissFocus() => FocusScope.of(context).unfocus();

  // ── NPI Registry search ──────────────────────────────────────────────────

  Future<void> _searchNpi() async {
    final first = _searchFirstController.text.trim();
    final last  = _searchLastController.text.trim();
    final state = _searchSelectedState ?? '';

    if (last.isEmpty) {
      setState(() => _searchError = 'Enter at least a last name to search');
      return;
    }

    _dismissFocus();
    setState(() { _searching = true; _searchError = null; _searchResults = []; });

    try {
      final uri = Uri.https('npiregistry.cms.hhs.gov', '/api/', {
        'version': '2.1',
        'limit': '20',
        'enumeration_type': 'NPI-1',
        if (first.isNotEmpty) 'first_name': first,
        'last_name': last,
        if (state.isNotEmpty) 'state': state,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('Server error ${response.statusCode}');

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? [])
          .map((r) => _NpiResult.fromJson(r as Map<String, dynamic>))
          .where((r) => r.lastName.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
        if (results.isEmpty) _searchError = 'No providers found — try a different name or state';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = 'Search failed: ${e.toString()}';
      });
    }
  }

  void _applyNpiResult(_NpiResult r) {
    _firstNameController.text  = _titleCase(r.firstName);
    _lastNameController.text   = _titleCase(r.lastName);
    _credentialController.text = r.credential;
    _specialtyController.text  = r.specialty;
    _phoneController.text      = r.phone;
    _addressController.text    = _titleCase(r.address);
    _cityController.text       = _titleCase(r.city);
    _selectedState             = r.state.isNotEmpty ? r.state : null;
    _zipController.text        = r.zip;
    _npiController.text        = r.npiNumber;
    setState(() {
      _searchExpanded = false;
      _searchResults = [];
    });
  }

  String _titleCase(String s) => s.isEmpty
      ? s
      : s.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');

  // ── Save / Delete ─────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Doctor'),
        content: Text('Remove ${widget.existing!.fullName} from your doctors list?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.deleteDoctor(widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _save() async {
    try {
      if (_formKey.currentState?.validate() != true) return;
      _dismissFocus();
      setState(() => _saving = true);

      final firstName = _firstNameController.text.trim();
      final lastName  = _lastNameController.text.trim();

      // Duplicate check: same first+last name (case-insensitive), excluding self when editing
      final existing = await StorageService.getDoctors();
      final isDuplicate = existing.any((d) {
        if (_isEditing && d.id == widget.existing!.id) return false;
        return d.firstName.toLowerCase() == firstName.toLowerCase() &&
               d.lastName.toLowerCase()  == lastName.toLowerCase();
      });

      if (isDuplicate) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$firstName $lastName is already in your doctors list.'),
            backgroundColor: const Color(0xFFF97316),
          ),
        );
        return;
      }

      final doctor = Doctor(
        id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        firstName:  firstName,
        lastName:   lastName,
        credential: _credentialController.text.trim(),
        specialty:  _specialtyController.text.trim(),
        phone:      _phoneController.text.trim(),
        address:    _addressController.text.trim(),
        city:       _cityController.text.trim(),
        state:      _selectedState ?? '',
        zip:        _zipController.text.trim(),
        npiNumber:  _npiController.text.trim(),
        notes:      _notesController.text.trim(),
      );

      if (_isEditing) {
        await StorageService.updateDoctor(doctor);
      } else {
        await StorageService.saveDoctor(doctor);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: ${e.toString()}')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Doctor' : 'Add Doctor',
          style: const TextStyle(color: Color(0xFF484141), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF484141)),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove doctor',
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          children: [
            _buildNpiSearchSection(),
            const SizedBox(height: 16),
            _buildNameSection(),
            const SizedBox(height: 16),
            _buildContactSection(),
            const SizedBox(height: 16),
            _buildAddressSection(),
            const SizedBox(height: 16),
            _buildNotesSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ── NPI search section ────────────────────────────────────────────────────

  Widget _buildNpiSearchSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() {
              _searchExpanded = !_searchExpanded;
              if (!_searchExpanded) _searchResults = [];
            }),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.search, color: _accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Search NPI Registry',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _accent)),
                        const SizedBox(height: 2),
                        Text('Find a doctor by name and state',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  Icon(
                    _searchExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          if (_searchExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _searchField(_searchFirstController, 'First Name')),
                      const SizedBox(width: 10),
                      Expanded(child: _searchField(_searchLastController, 'Last Name *')),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: _StateDropdown(
                          value: _searchSelectedState,
                          hint: 'State',
                          onChanged: (v) => setState(() => _searchSelectedState = v),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _searching ? null : _searchNpi,
                      icon: _searching
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search, size: 16),
                      label: Text(_searching ? 'Searching…' : 'Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchError != null) ...[
                    const SizedBox(height: 10),
                    Text(_searchError!,
                        style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('${_searchResults.length} result(s) — tap to select',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final r = _searchResults[i];
                          return InkWell(
                            onTap: () => _applyNpiResult(r),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_titleCase(r.firstName)} ${_titleCase(r.lastName)}'
                                          '${r.credential.isNotEmpty ? ', ${r.credential}' : ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF484141)),
                                        ),
                                      ),
                                      if (r.npiNumber.isNotEmpty)
                                        Text('NPI: ${r.npiNumber}',
                                            style: TextStyle(
                                                fontSize: 10, color: Colors.grey[400])),
                                    ],
                                  ),
                                  if (r.specialty.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(r.specialty,
                                        style: TextStyle(
                                            fontSize: 12, color: _accent,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                  if (r.city.isNotEmpty || r.state.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      [_titleCase(r.city), r.state]
                                          .where((s) => s.isNotEmpty).join(', '),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  // ── Form sections ─────────────────────────────────────────────────────────

  Widget _buildNameSection() {
    return _SectionCard(
      title: 'Doctor Info',
      icon: Icons.medical_services_outlined,
      iconColor: _accent,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('First Name', Icons.person_outlined),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Last Name *', Icons.person_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextFormField(
                controller: _credentialController,
                decoration: _dec('Credential', Icons.workspace_premium_outlined),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _specialtyController,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Specialty', Icons.biotech_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('e.g. MD, DO, NP, PA — specialty: Cardiology, Family Medicine…',
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildContactSection() {
    return _SectionCard(
      title: 'Contact',
      icon: Icons.phone_outlined,
      iconColor: const Color(0xFF22C55E),
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _dec('Phone Number', Icons.phone_outlined),
        ),
        if (_npiController.text.isNotEmpty || !_isEditing) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _npiController,
            keyboardType: TextInputType.number,
            decoration: _dec('NPI Number', Icons.tag_outlined),
          ),
        ],
      ],
    );
  }

  Widget _buildAddressSection() {
    return _SectionCard(
      title: 'Address',
      icon: Icons.location_on_outlined,
      iconColor: const Color(0xFFF97316),
      children: [
        TextFormField(
          controller: _addressController,
          textCapitalization: TextCapitalization.words,
          decoration: _dec('Street Address', Icons.home_outlined),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('City', Icons.location_city_outlined),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: _StateDropdown(
                value: _selectedState,
                hint: 'State',
                onChanged: (v) => setState(() => _selectedState = v),
                dense: false,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: TextFormField(
                controller: _zipController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: _dec('ZIP', Icons.markunread_mailbox_outlined).copyWith(counterText: ''),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return _SectionCard(
      title: 'Notes',
      icon: Icons.notes_outlined,
      iconColor: Colors.grey,
      children: [
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: _dec('Additional notes (optional)', Icons.notes_outlined),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _saving
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(_isEditing ? 'Update Doctor' : 'Save Doctor',
                style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accent)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red)),
      );
}

// ── NPI result model ──────────────────────────────────────────────────────────

class _NpiResult {
  final String npiNumber;
  final String firstName;
  final String lastName;
  final String credential;
  final String specialty;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String zip;

  const _NpiResult({
    required this.npiNumber,
    required this.firstName,
    required this.lastName,
    required this.credential,
    required this.specialty,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
  });

  factory _NpiResult.fromJson(Map<String, dynamic> json) {
    final basic = json['basic'] as Map<String, dynamic>? ?? {};
    final taxonomies = json['taxonomies'] as List<dynamic>? ?? [];
    final addresses = json['addresses'] as List<dynamic>? ?? [];

    // Primary taxonomy = specialty
    final primary = taxonomies.firstWhere(
      (t) => (t as Map)['primary'] == true,
      orElse: () => taxonomies.isNotEmpty ? taxonomies.first : <String, dynamic>{},
    ) as Map<String, dynamic>;

    // LOCATION address preferred
    final loc = addresses.firstWhere(
      (a) => (a as Map)['address_purpose'] == 'LOCATION',
      orElse: () => addresses.isNotEmpty ? addresses.first : <String, dynamic>{},
    ) as Map<String, dynamic>;

    return _NpiResult(
      npiNumber:  json['number'] as String? ?? '',
      firstName:  basic['first_name'] as String? ?? '',
      lastName:   basic['last_name'] as String? ?? '',
      credential: basic['credential'] as String? ?? '',
      specialty:  primary['desc'] as String? ?? '',
      phone:      (loc['telephone_number'] as String? ?? '').replaceAll('-', '-'),
      address:    loc['address_1'] as String? ?? '',
      city:       loc['city'] as String? ?? '',
      state:      loc['state'] as String? ?? '',
      zip:        (loc['postal_code'] as String? ?? '').take(5),
    );
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}

// ── US States ─────────────────────────────────────────────────────────────────

const _usStates = [
  ('AL', 'Alabama'),      ('AK', 'Alaska'),        ('AZ', 'Arizona'),
  ('AR', 'Arkansas'),     ('CA', 'California'),     ('CO', 'Colorado'),
  ('CT', 'Connecticut'),  ('DE', 'Delaware'),       ('DC', 'D.C.'),
  ('FL', 'Florida'),      ('GA', 'Georgia'),        ('HI', 'Hawaii'),
  ('ID', 'Idaho'),        ('IL', 'Illinois'),       ('IN', 'Indiana'),
  ('IA', 'Iowa'),         ('KS', 'Kansas'),         ('KY', 'Kentucky'),
  ('LA', 'Louisiana'),    ('ME', 'Maine'),           ('MD', 'Maryland'),
  ('MA', 'Massachusetts'),('MI', 'Michigan'),       ('MN', 'Minnesota'),
  ('MS', 'Mississippi'),  ('MO', 'Missouri'),       ('MT', 'Montana'),
  ('NE', 'Nebraska'),     ('NV', 'Nevada'),         ('NH', 'New Hampshire'),
  ('NJ', 'New Jersey'),   ('NM', 'New Mexico'),     ('NY', 'New York'),
  ('NC', 'North Carolina'),('ND', 'North Dakota'),  ('OH', 'Ohio'),
  ('OK', 'Oklahoma'),     ('OR', 'Oregon'),         ('PA', 'Pennsylvania'),
  ('RI', 'Rhode Island'), ('SC', 'South Carolina'), ('SD', 'South Dakota'),
  ('TN', 'Tennessee'),    ('TX', 'Texas'),           ('UT', 'Utah'),
  ('VT', 'Vermont'),      ('VA', 'Virginia'),        ('WA', 'Washington'),
  ('WV', 'West Virginia'),('WI', 'Wisconsin'),      ('WY', 'Wyoming'),
];

class _StateDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final ValueChanged<String?> onChanged;
  final bool dense;

  const _StateDropdown({
    required this.value,
    required this.hint,
    required this.onChanged,
    required this.dense,
  });

  static const _accent = Color(0xFF0EA5E9);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      isDense: dense,
      hint: Text(hint, style: TextStyle(fontSize: dense ? 12 : 14, color: Colors.grey[500])),
      decoration: InputDecoration(
        filled: true,
        fillColor: dense ? Colors.grey.shade50 : Colors.white,
        isDense: dense,
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 8 : 12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 8 : 12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 8 : 12),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
      items: _usStates.map((s) {
        return DropdownMenuItem<String>(
          value: s.$1,
          child: Text('${s.$1} – ${s.$2}',
              style: TextStyle(fontSize: dense ? 12 : 13),
              overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
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
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 0.6)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
