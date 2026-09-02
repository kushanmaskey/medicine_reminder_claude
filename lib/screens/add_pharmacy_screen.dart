import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/pharmacy.dart';
import '../services/storage_service.dart';

class AddPharmacyScreen extends StatefulWidget {
  final Pharmacy? existing;
  const AddPharmacyScreen({super.key, this.existing});

  @override
  State<AddPharmacyScreen> createState() => _AddPharmacyScreenState();
}

class _AddPharmacyScreenState extends State<AddPharmacyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController    = TextEditingController();
  final _phoneController   = TextEditingController();
  final _faxController     = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController    = TextEditingController();
  final _zipController     = TextEditingController();
  final _npiController     = TextEditingController();
  final _notesController   = TextEditingController();

  String? _selectedState;

  // Search
  final _searchNameController     = TextEditingController();
  final _searchLocationController = TextEditingController();
  bool _saving         = false;
  bool _fromSearch     = false; // true = show labels; false = show text fields
  bool _searchExpanded = false;
  bool _searching      = false;
  String? _searchError;
  List<_OsmPharmacyResult> _searchResults = [];

  bool get _isEditing => widget.existing != null;
  static const _accent = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _nameController.text    = e.name;
      _phoneController.text   = e.phone;
      _faxController.text     = e.fax;
      _addressController.text = e.address;
      _cityController.text    = e.city;
      _selectedState          = e.state.isNotEmpty ? e.state : null;
      _zipController.text     = e.zip;
      _npiController.text     = e.npiNumber;
      _notesController.text   = e.notes;
      _fromSearch = true; // existing data shows as labels
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _faxController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _npiController.dispose();
    _notesController.dispose();
    _searchNameController.dispose();
    _searchLocationController.dispose();
    super.dispose();
  }

  void _dismissFocus() => FocusScope.of(context).unfocus();

  // ── OpenStreetMap pharmacy search ─────────────────────────────────────────

  Future<void> _searchPharmacy() async {
    final name     = _searchNameController.text.trim();
    final location = _searchLocationController.text.trim();

    if (name.isEmpty) {
      setState(() => _searchError = 'Enter a pharmacy name');
      return;
    }

    _dismissFocus();
    setState(() { _searching = true; _searchError = null; _searchResults = []; });

    try {
      final query = location.isNotEmpty ? '$name $location' : name;
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'extratags': '1',
        'limit': '10',
        'countrycodes': 'us',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MedicalWalletApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) throw Exception('Server error ${response.statusCode}');

      final jsonList = jsonDecode(response.body) as List<dynamic>;
      final results = jsonList
          .map((r) => _OsmPharmacyResult.fromJson(r as Map<String, dynamic>))
          .where((r) => r.name.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
        if (results.isEmpty) _searchError = 'No results — try adding city or state (e.g. "CVS Keller TX")';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = 'Search failed: ${e.toString()}';
      });
    }
  }

  void _applyOsmResult(_OsmPharmacyResult r) {
    _nameController.text    = r.name;
    _phoneController.text   = r.phone;
    _faxController.text     = r.fax;
    _addressController.text = r.address;
    _cityController.text    = r.city;
    _selectedState          = r.stateAbbr.isNotEmpty ? r.stateAbbr : null;
    _zipController.text     = r.zip;
    _npiController.text     = r.npiNumber;
    setState(() {
      _fromSearch     = true;
      _searchExpanded = false;
      _searchResults  = [];
    });
  }

  // ── Save / Delete ──────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Pharmacy'),
        content: Text('Remove ${widget.existing!.name} from your pharmacies?'),
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
      await StorageService.deletePharmacy(widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _save() async {
    try {
      if (_formKey.currentState?.validate() != true) return;
      _dismissFocus();
      setState(() => _saving = true);

      final pharmacy = Pharmacy(
        id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name:      _nameController.text.trim(),
        npiNumber: _npiController.text.trim(),
        phone:     _phoneController.text.trim(),
        fax:       _faxController.text.trim(),
        address:   _addressController.text.trim(),
        city:      _cityController.text.trim(),
        state:     _selectedState ?? '',
        zip:       _zipController.text.trim(),
        notes:     _notesController.text.trim(),
      );

      if (_isEditing) {
        await StorageService.updatePharmacy(pharmacy);
      } else {
        await StorageService.savePharmacy(pharmacy);
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Pharmacy' : 'Add Pharmacy',
          style: const TextStyle(color: Color(0xFF484141), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF484141)),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove pharmacy',
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
            if (_fromSearch) ...[
              _buildPharmacyLabels(),
            ] else ...[
              _buildInfoSection(),
              const SizedBox(height: 16),
              _buildContactSection(),
              const SizedBox(height: 16),
              _buildAddressSection(),
            ],
            const SizedBox(height: 16),
            _buildNotesSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ── NPI search section ─────────────────────────────────────────────────────

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
                        Text('Search Pharmacy',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _accent)),
                        const SizedBox(height: 2),
                        Text('Find by name and city or ZIP code',
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
                  _searchField(_searchNameController, 'Pharmacy Name  (e.g. CVS, Walgreens)'),
                  const SizedBox(height: 8),
                  _searchField(_searchLocationController, 'City, ZIP, or State  (e.g. Keller TX)'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _searching ? null : _searchPharmacy,
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
                            onTap: () => _applyOsmResult(r),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF484141)),
                                  ),
                                  if (r.address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(r.address,
                                        style: TextStyle(fontSize: 12, color: _accent,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                  if (r.city.isNotEmpty || r.stateAbbr.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      [r.city, r.stateAbbr, r.zip]
                                          .where((s) => s.isNotEmpty).join(', '),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                  if (r.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(r.phone,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
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
      keyboardType: TextInputType.text,
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

  // ── Form sections ──────────────────────────────────────────────────────────

  Widget _buildPharmacyLabels() {
    final address = [
      _addressController.text,
      _cityController.text,
      _selectedState ?? '',
      _zipController.text,
    ].where((s) => s.isNotEmpty).join(', ');

    return _SectionCard(
      title: 'Pharmacy Info',
      icon: Icons.local_pharmacy_outlined,
      iconColor: _accent,
      children: [
        _labelRow(Icons.store_outlined, _nameController.text, large: true),
        if (_phoneController.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          _labelRow(Icons.phone_outlined, _phoneController.text),
        ],
        if (_faxController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _labelRow(Icons.fax_outlined, _faxController.text),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: 8),
          _labelRow(Icons.location_on_outlined, address),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _fromSearch = false),
          child: Text(
            'Enter manually instead',
            style: TextStyle(
              fontSize: 12,
              color: _accent,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _labelRow(IconData icon, String value, {bool large = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: large ? 15 : 13,
              fontWeight: large ? FontWeight.w700 : FontWeight.normal,
              color: large ? const Color(0xFF484141) : Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return _SectionCard(
      title: 'Pharmacy Info',
      icon: Icons.local_pharmacy_outlined,
      iconColor: _accent,
      children: [
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          maxLength: 150,
          decoration: _dec('Pharmacy Name *', Icons.store_outlined).copyWith(counterText: ''),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
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
          maxLength: 20,
          decoration: _dec('Phone Number', Icons.phone_outlined).copyWith(counterText: ''),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final digits = v.replaceAll(RegExp(r'\D'), '');
            if (digits.length < 7) return 'Enter a valid phone number';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _faxController,
          keyboardType: TextInputType.phone,
          maxLength: 20,
          decoration: _dec('Fax Number', Icons.fax_outlined).copyWith(counterText: ''),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final digits = v.replaceAll(RegExp(r'\D'), '');
            if (digits.length < 7) return 'Enter a valid fax number';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    final parts = [
      _addressController.text,
      _cityController.text,
      _selectedState ?? '',
      _zipController.text,
    ].where((s) => s.isNotEmpty).toList();

    return _SectionCard(
      title: 'Address',
      icon: Icons.location_on_outlined,
      iconColor: const Color(0xFFF97316),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, size: 16,
                color: parts.isEmpty ? Colors.grey[300] : Colors.grey[400]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                parts.isEmpty
                    ? 'Address auto-filled from search'
                    : parts.join(', '),
                style: TextStyle(
                  fontSize: 14,
                  color: parts.isEmpty ? Colors.grey[400] : Colors.grey[700],
                  fontStyle: parts.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
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
          maxLength: 500,
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
            : Text(_isEditing ? 'Update Pharmacy' : 'Save Pharmacy',
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

// ── OpenStreetMap pharmacy result model ───────────────────────────────────────

// US state name → abbreviation
const _stateAbbr = {
  'Alabama': 'AL', 'Alaska': 'AK', 'Arizona': 'AZ', 'Arkansas': 'AR',
  'California': 'CA', 'Colorado': 'CO', 'Connecticut': 'CT', 'Delaware': 'DE',
  'District of Columbia': 'DC', 'Florida': 'FL', 'Georgia': 'GA', 'Hawaii': 'HI',
  'Idaho': 'ID', 'Illinois': 'IL', 'Indiana': 'IN', 'Iowa': 'IA', 'Kansas': 'KS',
  'Kentucky': 'KY', 'Louisiana': 'LA', 'Maine': 'ME', 'Maryland': 'MD',
  'Massachusetts': 'MA', 'Michigan': 'MI', 'Minnesota': 'MN', 'Mississippi': 'MS',
  'Missouri': 'MO', 'Montana': 'MT', 'Nebraska': 'NE', 'Nevada': 'NV',
  'New Hampshire': 'NH', 'New Jersey': 'NJ', 'New Mexico': 'NM', 'New York': 'NY',
  'North Carolina': 'NC', 'North Dakota': 'ND', 'Ohio': 'OH', 'Oklahoma': 'OK',
  'Oregon': 'OR', 'Pennsylvania': 'PA', 'Rhode Island': 'RI', 'South Carolina': 'SC',
  'South Dakota': 'SD', 'Tennessee': 'TN', 'Texas': 'TX', 'Utah': 'UT',
  'Vermont': 'VT', 'Virginia': 'VA', 'Washington': 'WA', 'West Virginia': 'WV',
  'Wisconsin': 'WI', 'Wyoming': 'WY',
};

class _OsmPharmacyResult {
  final String name;
  final String phone;
  final String fax;
  final String npiNumber;
  final String address;
  final String city;
  final String stateAbbr;
  final String zip;

  const _OsmPharmacyResult({
    required this.name,
    required this.phone,
    this.fax = '',
    this.npiNumber = '',
    required this.address,
    required this.city,
    required this.stateAbbr,
    required this.zip,
  });

  factory _OsmPharmacyResult.fromJson(Map<String, dynamic> json) {
    final addr = json['address'] as Map<String, dynamic>? ?? {};
    final ext  = json['extratags'] as Map<String, dynamic>? ?? {};
    final stateFull = addr['state'] as String? ?? '';
    final houseNum  = addr['house_number'] as String? ?? '';
    final road      = addr['road'] as String? ?? '';
    final street    = [houseNum, road].where((s) => s.isNotEmpty).join(' ');
    final city      = addr['city'] as String?
        ?? addr['town'] as String?
        ?? addr['village'] as String?
        ?? addr['suburb'] as String?
        ?? '';
    final phone = ext['phone'] as String?
        ?? ext['contact:phone'] as String?
        ?? '';

    return _OsmPharmacyResult(
      name:       json['name'] as String? ?? '',
      phone:      phone,
      address:    street,
      city:       city,
      stateAbbr:  _stateAbbr[stateFull] ?? stateFull,
      zip:        addr['postcode'] as String? ?? '',
    );
  }
}

// ── US States ──────────────────────────────────────────────────────────────────

const _usStates = [
  ('AL', 'Alabama'),       ('AK', 'Alaska'),        ('AZ', 'Arizona'),
  ('AR', 'Arkansas'),      ('CA', 'California'),     ('CO', 'Colorado'),
  ('CT', 'Connecticut'),   ('DE', 'Delaware'),       ('DC', 'D.C.'),
  ('FL', 'Florida'),       ('GA', 'Georgia'),        ('HI', 'Hawaii'),
  ('ID', 'Idaho'),         ('IL', 'Illinois'),       ('IN', 'Indiana'),
  ('IA', 'Iowa'),          ('KS', 'Kansas'),         ('KY', 'Kentucky'),
  ('LA', 'Louisiana'),     ('ME', 'Maine'),           ('MD', 'Maryland'),
  ('MA', 'Massachusetts'), ('MI', 'Michigan'),       ('MN', 'Minnesota'),
  ('MS', 'Mississippi'),   ('MO', 'Missouri'),       ('MT', 'Montana'),
  ('NE', 'Nebraska'),      ('NV', 'Nevada'),         ('NH', 'New Hampshire'),
  ('NJ', 'New Jersey'),    ('NM', 'New Mexico'),     ('NY', 'New York'),
  ('NC', 'North Carolina'),('ND', 'North Dakota'),   ('OH', 'Ohio'),
  ('OK', 'Oklahoma'),      ('OR', 'Oregon'),         ('PA', 'Pennsylvania'),
  ('RI', 'Rhode Island'),  ('SC', 'South Carolina'), ('SD', 'South Dakota'),
  ('TN', 'Tennessee'),     ('TX', 'Texas'),           ('UT', 'Utah'),
  ('VT', 'Vermont'),       ('VA', 'Virginia'),        ('WA', 'Washington'),
  ('WV', 'West Virginia'), ('WI', 'Wisconsin'),      ('WY', 'Wyoming'),
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

  static const _accent = Color(0xFF8B5CF6);

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

// ── Section card ───────────────────────────────────────────────────────────────

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
