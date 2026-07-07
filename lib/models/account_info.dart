import 'package:equatable/equatable.dart';

/// Informations du compte Xtream (user_info).
class AccountInfo extends Equatable {
  final String username;
  final String status;
  final String? expDate; // timestamp unix (String) ou null
  final int maxConnections;

  const AccountInfo({
    required this.username,
    required this.status,
    required this.expDate,
    required this.maxConnections,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
        username: json['username']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        expDate: json['exp_date']?.toString(),
        maxConnections:
            int.tryParse(json['max_connections']?.toString() ?? '') ?? 1,
      );

  @override
  List<Object?> get props => [username, status, expDate];
}
