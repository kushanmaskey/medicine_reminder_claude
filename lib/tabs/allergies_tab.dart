import 'package:flutter/material.dart';
import '../models/allergy.dart';
import '../services/storage_service.dart';
import '../screens/add_allergy_screen.dart';

class AllergiesTab extends StatefulWidget {
  const AllergiesTab({super.key});

  @override
  State<AllergiesTab> createState() => AllergiesTabState();
}

class AllergiesTabState extends State<AllergiesTab> {
  List<Allergy> _allergies = [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await StorageService.getAllergies();
      if (mounted) setState(() { _allergies = list; _loading = false; _loadFailed = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  void reload() => _load();

  Future<void> openAdd() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const AddAllergyScreen()),
    );
    if (result == true || result == 'deleted') _load();
  }

  Future<void> _openEdit(Allergy a) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddAllergyScreen(existing: a)),
    );
    if (result == true || result == 'deleted') _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Could not load allergies', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 6),
              const Text('Check your internet connection and try again.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_allergies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.coronavirus, size: 64, color: Color(0xFFE2E8F0)),
            SizedBox(height: 16),
            Text(
              'No Allergies Recorded',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap + to add your first allergy',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _allergies.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _AllergyCard(
        allergy: _allergies[i],
        onTap: () => _openEdit(_allergies[i]),
      ),
    );
  }
}

class _AllergyCard extends StatelessWidget {
  final Allergy allergy;
  final VoidCallback onTap;
  const _AllergyCard({required this.allergy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.coronavirus,
                    color: Color(0xFFF59E0B), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: allergy.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (allergy.reason != null)
                        TextSpan(
                          text: '  ·  ${allergy.reason}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFFD97706),
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}
