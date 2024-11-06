import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class Medicine {
  int? id;
  String name;
  String frequency;
  String dosage;
  String schedule;
  TimeOfDay notificationTime;
  bool notificationsEnabled;
  int stock;
  DateTime startDate;
  DateTime endDate;

  Medicine({
    this.id,
    required this.name,
    required this.frequency,
    required this.dosage,
    required this.schedule,
    required this.notificationTime,
    required this.notificationsEnabled,
    required this.stock,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'dosage': dosage,
      'schedule': schedule,
      'notificationTime': '${notificationTime.hour}:${notificationTime.minute}',
      'notificationsEnabled': notificationsEnabled ? 1 : 0,
      'stock': stock,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  static Medicine fromMap(Map<String, dynamic> map) {
    final timeParts = map['notificationTime'].split(':');
    return Medicine(
      id: map['id'],
      name: map['name'],
      frequency: map['frequency'],
      dosage: map['dosage'],
      schedule: map['schedule'],
      notificationTime: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      notificationsEnabled: map['notificationsEnabled'] == 1,
      stock: map['stock'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
    );
  }
}

class MedicineModel with ChangeNotifier {
  final Database database;
  List<Medicine> _medicines = [];

  MedicineModel(this.database) {
    _loadMedicines();
  }

  List<Medicine> get medicines => _medicines;

  Future<void> _loadMedicines() async {
    final List<Map<String, dynamic>> maps = await database.query('medicines');
    _medicines = List.generate(maps.length, (i) => Medicine.fromMap(maps[i]));
    notifyListeners();
  }

  Future<void> addMedicine(Medicine medicine) async {
    final id = await database.insert(
      'medicines',
      medicine.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    medicine.id = id;
    _medicines.add(medicine);
    notifyListeners();
  }

  Future<void> updateMedicine(Medicine medicine) async {
    await database.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
    final index = _medicines.indexWhere((m) => m.id == medicine.id);
    if (index != -1) {
      _medicines[index] = medicine;
      notifyListeners();
    }
  }

  Future<void> removeMedicine(Medicine medicine) async {
    await database.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
    _medicines.remove(medicine);
    notifyListeners();
  }
}
