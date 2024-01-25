import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Blue Plus Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BluetoothDevicesScreen(),
    );
  }
}

class BluetoothDevicesScreen extends StatefulWidget {
  const BluetoothDevicesScreen({super.key});

  @override
  _BluetoothDevicesScreenState createState() => _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState extends State<BluetoothDevicesScreen> {
  // ignore: deprecated_member_use
  final FlutterBluePlus flutterBlue = FlutterBluePlus as FlutterBluePlus;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  void startScan() {
    setState(() {
      isScanning = true;
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Listen for scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.name == 'JPLSoil') {
          FlutterBluePlus.stopScan();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => DeviceServicesScreen(device: result.device),
          ));
          break;
        }
      }
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanning for JPLSoil'),
      ),
      body: Center(
        child: isScanning
            ? const CircularProgressIndicator()
            : const Text('Scan Complete. Click to rescan.'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => startScan(),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class DeviceServicesScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceServicesScreen({super.key, required this.device});

  @override
  _DeviceServicesScreenState createState() => _DeviceServicesScreenState();
}

class _DeviceServicesScreenState extends State<DeviceServicesScreen> {
  List<BluetoothService> services = [];
  Map<Guid, List<int>> characteristicData = {};

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  void connectToDevice() async {
    await widget.device.connect();
    discoverServices();
  }

  void discoverServices() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    setState(() {
      this.services = services;
    });
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        characteristic.setNotifyValue(true);
        characteristic.value.listen((value) {
          setState(() {
            characteristicData[characteristic.uuid] = value;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: ListView.builder(
        itemCount: services.length,
        itemBuilder: (context, index) {
          var service = services[index];
          return ListTile(
            title: Text('Service: ${service.uuid.toString()}'),
            subtitle: Column(
              children: service.characteristics.map((characteristic) {
                return ListTile(
                  title: Text('Characteristic: ${characteristic.uuid}'),
                  subtitle: Text(
                    'Data: ${characteristicData[characteristic.uuid]?.toString() ?? 'Waiting...'}',
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
