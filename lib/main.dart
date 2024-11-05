import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Initialize database
  final database = await openDatabase(
    join(await getDatabasesPath(), 'medicine_database.db'),
    onCreate: (db, version) {
      return db.execute(
        '''CREATE TABLE medicines(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          frequency TEXT,
          dosage TEXT,
          schedule TEXT,
          notificationTime TEXT,
          notificationsEnabled INTEGER,
          stock INTEGER,
          startDate TEXT,
          endDate TEXT
        )''',
      );
    },
    version: 1,
  );

  runApp(MedicineReminderApp(database: database));
}

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

class MedicineReminderApp extends StatelessWidget {
  final Database database;

  const MedicineReminderApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MedicineModel(database),
      child: MaterialApp(
        title: 'MediSync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const MedicineHomePage(),
      ),
    );
  }
}

class MedicineHomePage extends StatefulWidget {
  const MedicineHomePage({super.key});

  @override
  State<MedicineHomePage> createState() => _MedicineHomePageState();
}

class _MedicineHomePageState extends State<MedicineHomePage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final List<String> mealSchedules = [
    'Before Breakfast',
    'After Breakfast',
    'Before Lunch',
    'After Lunch',
    'Before Dinner',
    'After Dinner',
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    // Check notification permissions
    final bool? granted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _scheduleNotification(Medicine medicine) async {
    const androidDetails = AndroidNotificationDetails(
      'medisync_channel',
      'Medicine Reminder',
      channelDescription: 'Remind to take your medicine',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    // Cancel existing notifications for this medicine
    await flutterLocalNotificationsPlugin.cancel(medicine.id ?? 0);

    if (medicine.notificationsEnabled) {
      final now = DateTime.now();
      final scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        medicine.notificationTime.hour,
        medicine.notificationTime.minute,
      );

      // Schedule notification
      await flutterLocalNotificationsPlugin.zonedSchedule(
        medicine.id ?? 0,
        'Time to take ${medicine.name}',
        '${medicine.dosage} - ${medicine.schedule}',
        scheduledTime,
        platformDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _showMedicineDialog([Medicine? medicine]) async {
    final isEditing = medicine != null;
    final medicineNameController = TextEditingController(text: medicine?.name);
    final dosageController = TextEditingController(text: medicine?.dosage);
    final stockController =
        TextEditingController(text: medicine?.stock.toString());

    String selectedSchedule = medicine?.schedule ?? mealSchedules[0];
    TimeOfDay selectedTime = medicine?.notificationTime ?? TimeOfDay.now();
    bool notificationsEnabled = medicine?.notificationsEnabled ?? true;
    int stock = medicine?.stock ?? 0;

    await showDialog(
      context: this.context,
      builder: (BuildContext dialogOuterContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogInnerContext, StateSetter setState) {
            return AlertDialog(
              title: Text(isEditing ? "Edit Medicine" : "Add New Medicine"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: medicineNameController,
                      decoration:
                          const InputDecoration(labelText: "Medicine Name"),
                    ),
                    TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(
                          labelText: "Dosage (e.g., 2 pills)"),
                    ),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: "Stock Quantity"),
                      onChanged: (value) => stock = int.tryParse(value) ?? 0,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedSchedule,
                      decoration: const InputDecoration(labelText: "Schedule"),
                      items: mealSchedules.map((schedule) {
                        return DropdownMenuItem(
                          value: schedule,
                          child: Text(schedule),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedSchedule = value!);
                      },
                    ),
                    ListTile(
                      title: Text(
                          "Notification Time: ${selectedTime.format(dialogInnerContext)}"),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: dialogInnerContext,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setState(() => selectedTime = time);
                        }
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Enable Notifications"),
                      value: notificationsEnabled,
                      onChanged: (value) {
                        setState(() => notificationsEnabled = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.of(dialogOuterContext).pop(),
                ),
                ElevatedButton(
                  child: Text(isEditing ? "Update" : "Add"),
                  onPressed: () async {
                    final newMedicine = Medicine(
                      id: medicine?.id,
                      name: medicineNameController.text,
                      frequency: "Daily",
                      dosage: dosageController.text,
                      schedule: selectedSchedule,
                      notificationTime: selectedTime,
                      notificationsEnabled: notificationsEnabled,
                      stock: stock,
                      startDate: DateTime.now(),
                      endDate: DateTime.now().add(const Duration(days: 30)),
                    );

                    if (isEditing) {
                      await Provider.of<MedicineModel>(dialogOuterContext,
                              listen: false)
                          .updateMedicine(newMedicine);
                    } else {
                      if (medicineNameController.text.isEmpty ||
                          dosageController.text.isEmpty ||
                          stock <= 0) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Please fill in all fields with valid information")),
                        );
                        return;
                      }

                      await Provider.of<MedicineModel>(dialogOuterContext,
                              listen: false)
                          .addMedicine(newMedicine);
                    }

                    if (notificationsEnabled) {
                      await _scheduleNotification(newMedicine);
                    }

                    Navigator.of(dialogOuterContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediSync'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: DateTime.now(),
            calendarFormat: CalendarFormat.week,
            availableCalendarFormats: const {CalendarFormat.week: 'Week'},
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Consumer<MedicineModel>(
              builder: (context, medicineModel, child) {
                if (medicineModel.medicines.isEmpty) {
                  return const Center(child: Text('No medicines added.'));
                }
                return ListView.builder(
                  itemCount: medicineModel.medicines.length,
                  itemBuilder: (context, index) {
                    final medicine = medicineModel.medicines[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(medicine.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${medicine.dosage} - ${medicine.schedule}"),
                            Text("Stock: ${medicine.stock}"),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showMedicineDialog(medicine),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                await Provider.of<MedicineModel>(
                                  context,
                                  listen: false,
                                ).removeMedicine(medicine);
                                await flutterLocalNotificationsPlugin.cancel(
                                  medicine.id ?? 0,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMedicineDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
