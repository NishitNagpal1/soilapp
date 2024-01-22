import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Ensure this import points to your main.dart or wherever DatabaseHelper is located

class SensorDataScreen extends StatefulWidget {
  @override
  _SensorDataScreenState createState() => _SensorDataScreenState();
}

class _SensorDataScreenState extends State<SensorDataScreen> {
  late Future<List<SensorData>> sensorDataList;

  @override
  void initState() {
    super.initState();
    sensorDataList = DatabaseHelper()
        .getSensorDataList(); // Assuming DatabaseHelper is correctly implemented
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Sensor Data'),
      ),
      body: FutureBuilder<List<SensorData>>(
        future: sensorDataList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No sensor data available.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final sensorData = snapshot.data![index];
                return ListTile(
                  title: Text(
                      'Moisture: ${sensorData.moisture?.toStringAsFixed(2) ?? 'N/A'}, Voltage: ${sensorData.resistance?.toStringAsFixed(2) ?? 'N/A'}'),
                  subtitle: Text(
                      'Soil Type: ${sensorData.soilType}, Date & Time: ${sensorData.dateTime}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          'Lat: ${sensorData.latitude?.toStringAsFixed(2) ?? 'N/A'}'),
                      Text(
                          'Long: ${sensorData.longitude?.toStringAsFixed(2) ?? 'N/A'}'),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
