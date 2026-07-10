import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/purchase_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _loading = true;
  bool _purchasing = false;
  Package? _selectedPackage;

  static const _primary = Color(0xFF501513);

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await PurchaseService.getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _selectedPackage = offerings?.current?.annual ?? offerings?.current?.monthly;
        _loading = false;
      });
    }
  }

  Future<void> _purchase() async {
    if (_selectedPackage == null) return;
    setState(() => _purchasing = true);
    try {
      final success = await PurchaseService.purchasePackage(_selectedPackage!);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() => _purchasing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _purchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    final restored = await PurchaseService.restorePurchases();
    if (mounted) {
      setState(() => _purchasing = false);
      if (restored) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous purchases found.')),
        );
      }
    }
  }

  String _priceText(Package pkg) {
    final price = pkg.storeProduct.priceString;
    if (pkg.packageType == PackageType.annual) {
      return '$price / year';
    }
    return '$price / month';
  }

  String _savingsText(List<Package> packages) {
    final monthly = packages.firstWhere(
      (p) => p.packageType == PackageType.monthly,
      orElse: () => packages.first,
    );
    final annual = packages.firstWhere(
      (p) => p.packageType == PackageType.annual,
      orElse: () => packages.first,
    );
    if (monthly.packageType == annual.packageType) return '';
    final monthlyAnnual = monthly.storeProduct.price * 12;
    final annualPrice = annual.storeProduct.price;
    if (monthlyAnnual <= 0) return '';
    final savings = ((monthlyAnnual - annualPrice) / monthlyAnnual * 100).round();
    return 'Save $savings%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final packages = _offerings?.current?.availablePackages ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services, color: _primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'My Medical Wallet Premium',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Get full access to all features',
            style: TextStyle(fontSize: 15, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildFeatureList(),
          const SizedBox(height: 24),
          if (packages.isNotEmpty) ...[
            ...packages.map((pkg) => _buildPackageTile(pkg, packages)),
            const SizedBox(height: 8),
            Text(
              'Start with 1 month free, cancel anytime.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _purchasing ? null : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _purchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Start Free Trial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _purchasing ? null : _restore,
              child: const Text('Restore Purchases', style: TextStyle(color: Colors.black54)),
            ),
          ] else
            const Text('Unable to load subscription options. Please try again later.'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    const features = [
      'Medication tracking & reminders',
      'Appointment management',
      'Vitals & health history',
      'Doctor & insurance records',
      'Prescription management',
      'Allergy tracking',
      'Activity log',
    ];
    return Column(
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: _primary, size: 20),
                    const SizedBox(width: 12),
                    Text(f, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildPackageTile(Package pkg, List<Package> allPackages) {
    final isSelected = _selectedPackage?.identifier == pkg.identifier;
    final isAnnual = pkg.packageType == PackageType.annual;
    final savings = isAnnual ? _savingsText(allPackages) : '';

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = pkg),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? _primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? _primary.withValues(alpha: 0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? _primary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAnnual ? 'Yearly' : 'Monthly',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (isAnnual)
                    const Text(
                      '1 month free trial included',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _priceText(pkg),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (savings.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      savings,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
