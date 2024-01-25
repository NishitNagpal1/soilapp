import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Import your database helper

class SensorDataScreen extends StatefulWidget {
  const SensorDataScreen({super.key});

  @override
  State<SensorDataScreen> createState() => _SensorDataScreenState();
}

class _SensorDataScreenState extends State<SensorDataScreen> {
  late Future<List<SensorData>> sensorDataList;

  @override
  void initState() {
    super.initState();
    sensorDataList = DatabaseHelper().getSensorDataList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Sensor Data'),
      ),
      body: FutureBuilder<List<SensorData>>(
        future: sensorDataList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No sensor data available.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final sensorData = snapshot.data![index];
                return ListTile(
                  title: Text('Moisture: ${sensorData.moisture}'),
                  subtitle: Text('Resistance: ${sensorData.resistance}'),
                  trailing: Text('Date & Time: ${sensorData.dateTime}'),
                );
              },
            );
          }
        },
      ),
    );
  }
}
