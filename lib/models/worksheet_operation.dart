// lib/models/worksheet_operation.dart
class WorkSheetOperation {
  final String id;
  final String code;

  WorkSheetOperation({required this.id, required this.code});

  factory WorkSheetOperation.fromJson(Map<String, dynamic> json) {
    return WorkSheetOperation(
      id: json['id'].toString(),
      code: json['code'].toString(),
    );
  }
}