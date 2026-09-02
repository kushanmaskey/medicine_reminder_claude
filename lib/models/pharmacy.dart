class Pharmacy {
  final String id;
  final String name;
  final String npiNumber;
  final String phone;
  final String fax;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String notes;

  Pharmacy({
    required this.id,
    this.name = '',
    this.npiNumber = '',
    this.phone = '',
    this.fax = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.notes = '',
  });

  String get fullAddress {
    final parts = [address, city, state, zip].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'npiNumber': npiNumber,
        'phone': phone,
        'fax': fax,
        'address': address,
        'city': city,
        'state': state,
        'zip': zip,
        'notes': notes,
      };

  factory Pharmacy.fromJson(Map<String, dynamic> json) => Pharmacy(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        npiNumber: json['npiNumber'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        fax: json['fax'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        zip: json['zip'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}
