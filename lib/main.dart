// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/sensor_data_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import "package:flutter_application_1/readingsensordata.dart";
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => BluetoothStateProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class LocationService {
  final Location location = Location();

  Stream<LocationData>? _locationStream;

  Stream<LocationData> get locationStream {
    _locationStream ??= location.onLocationChanged;
    return _locationStream!;
  }

  Future<void> initializeLocationService() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check and request location service
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    // Check and request permission
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    // Start listening to the location stream
    location.onLocationChanged.listen((LocationData currentLocation) {
      // Use currentLocation with your logic
    });
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double? currentLatitude;
  double? currentLongitude;
  StreamSubscription<LocationData>? locationSubscription;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Stream<String> _dateTimeStream;
  String _selectedSoilType = 'Loam'; // Default soil type
  FlutterBluePlus flutterBluePlus = FlutterBluePlus();
  BluetoothDevice? connectedDevice;
  bool isScanning = false;
  DatabaseHelper databaseHelper = DatabaseHelper();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  double? latestMoistureValue;
  double? latestResistanceValue;
  String? latestDateTime;
  StreamController<double?> moistureStreamController =
      StreamController<double?>();
  StreamController<double?> resistanceStreamController =
      StreamController<double?>();
  Map<String, List<double>> customSoilTypes = {
    'Loam': [0.56, -0.059],
    'Sandy Loam': [0.50, -0.062],
  };
  void _exportAndShareCsv() async {
    try {
      String csvData = await databaseHelper.convertDataToCsv();
      File csvFile = await databaseHelper.saveCsvToFile(csvData);

      Share.shareFiles([csvFile.path], text: 'Sensor Data CSV');
    } catch (e) {
      print("Error exporting data: $e");
    }
  }

  // Database helper instance

  @override
  void initState() {
    super.initState();
    LocationService().initializeLocationService();
    // Listen to the location stream and update state with new data
    locationSubscription =
        LocationService().locationStream.listen((locationData) {
      setState(() {
        currentLatitude = locationData.latitude;
        currentLongitude = locationData.longitude;
      });
    });
    _dateTimeStream = Stream.periodic(const Duration(seconds: 1), (count) {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      return 'Date: $formattedDate';
    });
  }

  @override
  void dispose() {
    // Cancel the subscription when the widget is disposed
    locationSubscription?.cancel();
    super.dispose();
  }

  bool isKeyboardOpen(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom != 0;
  }

  void _showAddSoilTypeDialog() {
    String newSoilTypeName = '';
    String newConstantA = '';
    String newConstantB = '';
    BuildContext dialogContext = _scaffoldKey.currentContext!;

    // Ensure correct BuildContext usage:
    showDialog(
      context:
          dialogContext, // Assuming context is available within the widget tree
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Soil Type'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Set a maximum height for the dialog if necessary
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              // Wrap with SingleChildScrollView
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    onChanged: (value) => newSoilTypeName = value,
                    decoration:
                        const InputDecoration(labelText: 'Soil Type Name'),
                  ),
                  TextField(
                    onChanged: (value) => newConstantA = value,
                    decoration:
                        const InputDecoration(labelText: 'Constant A (m)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    onChanged: (value) => newConstantB = value,
                    decoration:
                        const InputDecoration(labelText: 'Constant B (c)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (newSoilTypeName.isEmpty ||
                    newConstantA.isEmpty ||
                    newConstantB.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Complete all fields")),
                  );
                } else {
                  // Ensure setState calls are within a StatefulWidget:
                  setState(() {
                    customSoilTypes[newSoilTypeName] = [
                      double.tryParse(newConstantA) ?? 0.0,
                      double.tryParse(newConstantB) ?? 0.0
                    ];
                    _selectedSoilType = newSoilTypeName;
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Start scanning for the "JPLSoil" device
  void _startScanning(BuildContext context) {
    final bluetoothStateProvider = Provider.of<BluetoothStateProvider>(
      context,
      listen: false,
    );
    bluetoothStateProvider.startScanning();

    // Set the scan status
    setState(() {
      isScanning = true;
    });

    FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult r in results) {
          if (r.device.platformName == "JPLSoil") {
            // Connect to the "JPLSoil" device
            _connectToDevice(r.device);
            break; // Stop scanning when the target device is found
          }
        }
      },
      onError: (error) {
        print('Scan error: $error');
      },
    );
  }

  Future<void> updateSensorValues(ParsedSensorData sensorData) async {
    double m, c;
    if (_selectedSoilType == 'Loam') {
      m = 0.56;
      c = -0.059;
    } else {
      m = 0.50;
      c = -0.062;
    }

    // Remove the local variable declarations

    if (sensorData.type == DataType.FDR_VOLTAGE) {
      double adjustedMoisture = (m * sensorData.value + c) * 100;
      double adjustedResistance = sensorData.value;

      setState(() {
        latestMoistureValue =
            adjustedMoisture.abs(); // Update instance variable
        latestResistanceValue = adjustedResistance; // Update instance variable
      });

      moistureStreamController.add(latestMoistureValue);
      resistanceStreamController.add(latestResistanceValue);
    }
  }

  void _connectToDevice(BluetoothDevice device) {
    if (connectedDevice == device) {
      return;
    }
    void _onDataAvailable(value) {
      // Print the raw byte data
      print("Raw data received: $value");

      // Convert bytes to a string and print the decoded string
      String dataString = utf8.decode(value);
      print("Decoded string: $dataString");

      // Process the data string
      ParsedSensorData sensorData = ParsedSensorData.fromDeviceData(dataString);

      // Update your application state based on the sensor data
      updateSensorValues(sensorData);
    }

    device.connect().then((_) {
      // Device is connected
      setState(() {
        connectedDevice = device;
        isScanning = false;
      });

      device.discoverServices().then((services) {
        for (BluetoothService service in services) {
          if (service.uuid.toString() ==
              "6e400001-b5a3-f393-e0a9-e50e24dcca9e") {
            for (BluetoothCharacteristic characteristic
                in service.characteristics) {
              if (characteristic.uuid.toString() ==
                  "6e400003-b5a3-f393-e0a9-e50e24dcca9e") {
                characteristic.setNotifyValue(true);
                characteristic.value.listen((value) {
                  _onDataAvailable(value);
                });
              }
            }
          }
        }
      });

      device.connectionState.listen((event) {
        if (event == BluetoothConnectionState.disconnected) {
          setState(() {
            connectedDevice = null;
          });
          // Attempt to reconnect after a delay
          Future.delayed(const Duration(seconds: 5), () {
            _connectToDevice(device);
          });
        }
      });
    }).catchError((error) {
      // Handle connection error
      print('Connection error: $error');
      setState(() {
        connectedDevice = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: Scaffold(
        resizeToAvoidBottomInset: true,
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Data Collection'),
        ),
        body: GestureDetector(
          onHorizontalDragUpdate: (details) {
            print("Swipe detected: delta.dx = ${details.delta.dx}");
            if (details.delta.dx > 0) {
              // Right swipe
              print("Right swipe");
              navigatorKey.currentState!.push(
                MaterialPageRoute(builder: (context) => const SecondPage()),
              );
              // Add right swipe handling logic here
            } else if (details.delta.dx < 0) {
              // Left swipe
              print("Left swipe");
              // Add left swipe handling logic here
            }
          },
          child: ListView(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Sensor Readings:',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.left,
              ),
              const Text(
                'Soil Moisture and Temperature Sensor',
                style: TextStyle(
                  fontSize: 20,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StreamBuilder<double?>(
                    stream: moistureStreamController.stream,
                    builder: (context, snapshot) {
                      final moistureValue = snapshot.data;
                      return DataTile(
                        title:
                            'Moisture: ${moistureValue?.toStringAsFixed(2) ?? 'N/A'}',
                        backgroundColor: Colors.green,
                      );
                    },
                  ),
                  StreamBuilder<double?>(
                    stream: resistanceStreamController.stream,
                    builder: (context, snapshot) {
                      final resistanceValue = snapshot.data;
                      return DataTile(
                        title: 'Voltage: ${resistanceValue ?? 'N/A'}',
                        backgroundColor: Colors.orange,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const DataTile(
                    title: 'Temperature',
                    backgroundColor: Colors.teal,
                  ),
                  StreamBuilder<String>(
                    stream: _dateTimeStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return DataTile(
                            title: snapshot.data!,
                            backgroundColor: Colors.cyan);
                      } else {
                        return const DataTile(
                            title: 'Loading...', backgroundColor: Colors.cyan);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Soil Type:',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.left,
              ),
              DropdownButton<String>(
                value: _selectedSoilType,
                onChanged: (newValue) {
                  if (newValue == 'Add Custom Soil Type') {
                    _showAddSoilTypeDialog();
                  } else {
                    setState(() {
                      _selectedSoilType = newValue!;
                    });
                  }
                },
                items: customSoilTypes.keys
                    .toList()
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList()
                  ..add(const DropdownMenuItem(
                    value: 'Add Custom Soil Type',
                    child: Text('Add Custom Soil Type'),
                  )),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 150,
                    height: 110,
                    child: ElevatedButton(
                      onPressed: () {
                        // Start scanning for the "JPLSoil" device
                        _startScanning(context);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(40),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.grey,
                        elevation: 5,
                      ),
                      child: Text(connectedDevice != null
                          ? 'Connected to Device'
                          : 'READ'),
                    ),
                  ),
                  Container(
                      width: 150,
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10), // Apply rounded corners
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          final sensorDataEntry = SensorData(
                            moisture:
                                latestMoistureValue, // Default to 0.0 if null
                            resistance:
                                latestResistanceValue, // Default to 0.0 if null
                            dateTime: latestDateTime ??
                                DateFormat('yyyy-MM-dd HH:mm:ss').format(
                                    DateTime.now()), // Current time if null
                            soilType:
                                _selectedSoilType, // Default to "Unknown" if null
                            latitude: currentLatitude ??
                                0.0, // Default to 0.0 if null
                            longitude: currentLongitude ??
                                0.0, // Default to 0.0 if null
                          );

                          databaseHelper
                              .insertSensorData(sensorDataEntry)
                              .then((_) {
                            print(
                                'Data saved successfully'); // Debugging statement
                          }).catchError((error) {
                            print(
                                'Error saving data: $error'); // Error handling
                          });

                          // Reset the instance variables
                          setState(() {
                            latestMoistureValue = null;
                            latestResistanceValue = null;
                            latestDateTime = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(40),
                            foregroundColor: Colors.white,
                            backgroundColor:
                                const Color.fromARGB(255, 154, 97, 76),
                            elevation: 5),
                        child: const Text('Save Data'),
                      )),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: 150,
                    height:
                        110, // Makes the button span the width of the screen
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(30), // Apply rounded corners
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        navigatorKey.currentState?.push(
                          MaterialPageRoute(
                              builder: (context) => const SensorDataScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        // padding: const EdgeInsets.all(40),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red.shade300,
                        elevation: 5,
                      ),
                      child: const Text('View Saved Sensor Data'),
                    ),
                  ),
                  // New Button for Exporting and Sharing CSV
                  Container(
                    width: 150,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ElevatedButton(
                      onPressed: _exportAndShareCsv,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        // padding: const EdgeInsets.all(40),
                        foregroundColor: Colors.white,
                        backgroundColor:
                            const Color.fromARGB(255, 158, 235, 69),
                        elevation: 5, // Text color
                      ),
                      child: const Text('Export and Share CSV'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DataTile extends StatelessWidget {
  final String title;
  final Color backgroundColor;

  const DataTile(
      {super.key, required this.title, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 130,
      decoration: BoxDecoration(
        border: Border.all(color: backgroundColor, width: 2),
        borderRadius: BorderRadius.circular(15),
        color: backgroundColor,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Detect swipe in the left direction
        if (details.delta.dx < 0) {
          // Navigate back
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Second Page'),
        ),
        body: const SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Text(
                  'Sensor Readings:',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
                Text(
                  'Resistance Moisture Sensor',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.left,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DataTile(
                      title: 'R. Humidity',
                      backgroundColor: Colors.green,
                    ),
                    DataTile(
                      title: 'Air Temp',
                      backgroundColor: Colors.orange,
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DataTile(
                      title: 'Solar Radiation',
                      backgroundColor: Colors.teal,
                    ),
                    DataTile(
                      title: 'ET',
                      backgroundColor: Colors.cyan,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@override
State<StatefulWidget> createState() {
  // TODO: implement createState
  throw UnimplementedError();
}

class BluetoothStateProvider with ChangeNotifier {
  BluetoothAdapterState _bluetoothState = BluetoothAdapterState.unknown;

  BluetoothAdapterState get bluetoothState => _bluetoothState;

  void startScanning() {
    // Start scanning for the "JPLSoil" device
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
  }

  void setBluetoothState(BluetoothAdapterState state) {
    _bluetoothState = state;
    notifyListeners();
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper.internal();
  factory DatabaseHelper() => _instance;
  static Database? _db;

  DatabaseHelper.internal();

  Future<Database?> get db async {
    if (_db != null) {
      return _db;
    }
    _db = await initDb();
    return _db;
  }

  Future<Database> initDb() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'sensor_data.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (Database db, int version) async {
        await db.execute('''
        CREATE TABLE SensorData (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          moisture REAL,
          resistance REAL,
          dateTime TEXT,
          soilType TEXT,
          latitude REAL,  
          longitude REAL 
        )
      ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Handle database upgrades if necessary
      },
    );
  }

  // Insert data into the database
  Future<int> insertSensorData(SensorData sensorData) async {
    Database? dbClient = await db;
    return await dbClient!.insert('SensorData', sensorData.toMap());
  }

  Future<String> convertDataToCsv() async {
    Database? dbClient = await db;
    if (dbClient == null) {
      throw Exception('Database not available');
    }

    List<Map<String, dynamic>> maps =
        await dbClient.query('SensorData', orderBy: 'dateTime DESC');

    String csv =
        'id, moisture, resistance, dateTime, soilType, latitude, longitude\n';
    for (var row in maps) {
      csv +=
          '${row['id']},${row['moisture']},${row['resistance']},${row['dateTime']},${row['soilType']},${row['latitude']},${row['longitude']}\n';
    }
    return csv;
  }

  Future<File> saveCsvToFile(String csvString) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/sensor_data.csv';
    final File file = File(path);

    return file.writeAsString(csvString);
  }

  // Retrieve all sensor data from the database
  Future<List<SensorData>> getSensorDataList() async {
    Database? dbClient = await db;
    List<Map<String, dynamic>> maps =
        await dbClient!.query('SensorData', orderBy: 'dateTime DESC');
    List<SensorData> sensorDataList = [];

    for (Map<String, dynamic> map in maps) {
      sensorDataList.add(SensorData.fromMap(map));
    }

    return sensorDataList;
  }
}

class SensorData {
  int? id;
  double? moisture; // Nullable double
  double? resistance; // Nullable double
  String dateTime;
  String soilType;
  double? latitude;
  double? longitude;

  SensorData({
    this.id,
    this.moisture,
    required this.dateTime,
    required this.soilType,
    this.latitude,
    this.longitude,
    required this.resistance,
  });

  factory SensorData.fromMap(Map<String, dynamic> map) {
    double? parseDouble(dynamic value) {
      if (value == null || value == 'N/A') {
        return null;
      }
      return value is double ? value : double.tryParse(value.toString());
    }

    String parseString(dynamic value) {
      if (value == null) {
        return 'N/A';
      }
      return value.toString();
    }

    int? parseInt(dynamic value) {
      if (value == null) {
        return null;
      }
      return value is int ? value : int.tryParse(value.toString());
    }

    return SensorData(
      id: parseInt(map['id']),
      moisture: parseDouble(map['moisture']),
      resistance: parseDouble(map['resistance']),
      dateTime: parseString(map['dateTime']),
      soilType: parseString(map['soilType']),
      latitude: parseDouble(map['latitude']),
      longitude: parseDouble(map['longitude']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moisture': moisture ?? 0.0, // Replace null with default value
      'resistance': resistance ?? 0.0, // Replace null with default value
      'dateTime': dateTime,
      'soilType': soilType,
      'latitude': latitude ?? 0.0, // Replace null with default value
      'longitude': longitude ?? 0.0, // Replace null with default value
    };
  }
}
