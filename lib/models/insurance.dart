class Insurance {
  final String id;
  final String type; // 'Health', 'Dental', 'Vision'
  final String providerName;
  final String planName;
  final String memberId;
  final String groupNumber;
  final DateTime? effectiveDate;
  final DateTime? expirationDate;
  final String phone;
  final String copay;
  final String deductible;
  final String notes;

  Insurance({
    required this.id,
    this.type = 'Health',
    required this.providerName,
    this.planName = '',
    this.memberId = '',
    this.groupNumber = '',
    this.effectiveDate,
    this.expirationDate,
    this.phone = '',
    this.copay = '',
    this.deductible = '',
    this.notes = '',
  });

  bool get isExpired {
    if (expirationDate == null) return false;
    return expirationDate!.isBefore(DateTime.now());
  }

  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    final daysLeft = expirationDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 30;
  }
}
