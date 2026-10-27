class ProwlarrHealthItem {
  final String status;
  final String message;

  const ProwlarrHealthItem({
    required this.status,
    required this.message,
  });

  factory ProwlarrHealthItem.fromJson(Map<String, dynamic> json) {
    return ProwlarrHealthItem(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
    );
  }

  @override
  String toString() {
    return 'ProwlarrHealthItem(status: $status, message: $message)';
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
    };
  }
}
