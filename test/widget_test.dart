import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Import your main app file
import 'package:medapp/main.dart';

void main() {
  // Initialize FFI for testing
  late Database database;

  setUpAll(() async {
    // Initialize FFI
    sqfliteFfiInit();
    // Set global factory for tests
    databaseFactory = databaseFactoryFfi;

    // Create in-memory database for testing
    database = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
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
    );
  });

  tearDownAll(() async {
    await database.close();
  });

  group('Medicine Reminder App Widget Tests', () {
    testWidgets('App title is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));
      expect(find.text('mediSync'), findsOneWidget);
    });

    testWidgets('Add medicine button is present', (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Empty state message is shown when no medicines',
        (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));
      expect(find.text('No medicines added.'), findsOneWidget);
    });

    testWidgets('Can open add medicine dialog', (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));

      // Tap the add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Add New Medicine'), findsOneWidget);
      expect(find.byType(TextField),
          findsNWidgets(3)); // Name, dosage, stock fields
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('Can add new medicine', (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));

      // Open add dialog
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Fill in medicine details
      await tester.enterText(
          find.widgetWithText(TextField, 'Medicine Name'), 'Test Medicine');
      await tester.enterText(
          find.widgetWithText(TextField, 'Dosage (e.g., 2 pills)'), '1 pill');
      await tester.enterText(
          find.widgetWithText(TextField, 'Stock Quantity'), '30');

      // Tap add button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Verify medicine was added
      expect(find.text('Test Medicine'), findsOneWidget);
      expect(find.text('1 pill'), findsOneWidget);
    });

    testWidgets('Can delete medicine', (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));

      // First add a medicine
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Medicine Name'),
          'Delete Test Medicine');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Verify medicine was added
      expect(find.text('Delete Test Medicine'), findsOneWidget);

      // Delete the medicine
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      // Verify medicine was deleted
      expect(find.text('Delete Test Medicine'), findsNothing);
    });

    testWidgets('Can edit medicine', (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));

      // First add a medicine
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Medicine Name'),
          'Edit Test Medicine');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Modify medicine name
      await tester.enterText(
          find.widgetWithText(TextField, 'Medicine Name'), 'Updated Medicine');
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      // Verify medicine was updated
      expect(find.text('Updated Medicine'), findsOneWidget);
      expect(find.text('Edit Test Medicine'), findsNothing);
    });

    testWidgets('Meal schedule dropdown shows all options',
        (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));

      // Open add dialog
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Tap the dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Verify all meal schedule options are present
      expect(find.text('Before Breakfast'), findsOneWidget);
      expect(find.text('After Breakfast'), findsOneWidget);
      expect(find.text('Before Lunch'), findsOneWidget);
      expect(find.text('After Lunch'), findsOneWidget);
      expect(find.text('Before Dinner'), findsOneWidget);
      expect(find.text('After Dinner'), findsOneWidget);
    });

    testWidgets('Notification toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(MedicineReminderApp(database: database));

      // Open add dialog
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Find and tap notification toggle
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Verify initial state (enabled by default)
      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, true);

      // Toggle notifications off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify toggle state changed
      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, false);
    });
  });
}
