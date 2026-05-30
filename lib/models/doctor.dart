class Doctor {
  final String id;
  final String firstName;
  final String lastName;
  final String credential; // MD, DO, NP, PA, etc.
  final String specialty;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String npiNumber;
  final String notes;

  Doctor({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.credential = '',
    this.specialty = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.npiNumber = '',
    this.notes = '',
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return credential.isNotEmpty ? '$name, $credential' : name;
  }

  String get displayName => '$firstName $lastName'.trim();

  String get fullAddress {
    final parts = [address, city, state, zip].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'credential': credential,
        'specialty': specialty,
        'phone': phone,
        'address': address,
        'city': city,
        'state': state,
        'zip': zip,
        'npiNumber': npiNumber,
        'notes': notes,
      };

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        credential: json['credential'] as String? ?? '',
        specialty: json['specialty'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        zip: json['zip'] as String? ?? '',
        npiNumber: json['npiNumber'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}
