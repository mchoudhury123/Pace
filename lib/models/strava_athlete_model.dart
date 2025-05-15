class StravaAthleteModel {
  final int id;
  final String? firstname;
  final String? lastname;
  final String? city;
  final String? country;
  final String? profile; // Profile image URL
  final String? sex;
  final int? resourceState;
  final String? username;
  
  StravaAthleteModel({
    required this.id,
    this.firstname,
    this.lastname,
    this.city,
    this.country,
    this.profile,
    this.sex,
    this.resourceState,
    this.username,
  });
  
  // Create from JSON
  factory StravaAthleteModel.fromJson(Map<String, dynamic> json) {
    return StravaAthleteModel(
      id: json['id'] as int,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      profile: json['profile'] as String?,
      sex: json['sex'] as String?,
      resourceState: json['resource_state'] as int?,
      username: json['username'] as String?,
    );
  }
  
  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstname': firstname,
      'lastname': lastname,
      'city': city,
      'country': country,
      'profile': profile,
      'sex': sex,
      'resource_state': resourceState,
      'username': username,
    };
  }
  
  // Get full name
  String get fullName => '$firstname $lastname'.trim();
}
