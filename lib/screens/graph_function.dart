import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hamster_project/theme/app_theme.dart';

class GraphFunctionScreen extends StatefulWidget {
  const GraphFunctionScreen({super.key});

  @override
  State<GraphFunctionScreen> createState() => _GraphFunctionScreenState();
}

class HealthRecord {
  final DateTime date;
  final double distance;
  final String note;

  HealthRecord(this.date, this.distance, this.note);
}

class _GraphFunctionScreenState extends State<GraphFunctionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _wheelRotationController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final userId = FirebaseAuth.instance.currentUser!.uid;
  double? _wheelDiameter;
  double? _calculatedDistance;

  late ZoomPanBehavior _zoomPanBehavior;
  late TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();
    _loadWheelDiameter();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      zoomMode: ZoomMode.xy,
      enablePanning: true,
    );
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      header: '',
      format: 'point.note',
    );
  }

  Future<void> _loadWheelDiameter() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('breeding_environments')
        .doc('main_env')
        .get();

    setState(() {
      _wheelDiameter =
          double.tryParse(docSnapshot.data()?['wheelDiameter'] ?? '0');
    });
  }

  void _onWheelRotationChanged(String value) {
    final rotation = int.tryParse(value);
    if (_wheelDiameter != null && rotation != null) {
      final dist = rotation * 3.1416 * _wheelDiameter! * 0.01;
      setState(() {
        _calculatedDistance = dist;
      });
    } else {
      setState(() {
        _calculatedDistance = null;
      });
    }
  }

  void _addRecord() async {
    if (_formKey.currentState!.validate()) {
      final wheelRotation = int.parse(_wheelRotationController.text);
      final distance = _calculatedDistance ?? 0.0;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'has_subcollections': true}, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('health_records')
          .add({
        'date': Timestamp.fromDate(DateTime.parse(_dateController.text)),
        'wheel_rotation': wheelRotation,
        'distance': distance,
        'note': _noteController.text,
      });

      _dateController.clear();
      _wheelRotationController.clear();
      _noteController.clear();
      setState(() => _calculatedDistance = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('記録を追加しました！')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration:
                            const InputDecoration(labelText: '日付 (YYYY-MM-DD)'),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 2),
                            lastDate: DateTime(DateTime.now().year + 2),
                          );
                          if (picked != null) {
                            _dateController.text =
                                picked.toIso8601String().substring(0, 10);
                          }
                        },
                      ),
                      TextFormField(
                        controller: _wheelRotationController,
                        decoration:
                            const InputDecoration(labelText: 'Wheel回転数'),
                        keyboardType: TextInputType.number,
                        onChanged: _onWheelRotationChanged,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            const Text('走った距離（m）：'),
                            Text(
                              _calculatedDistance != null
                                  ? _calculatedDistance!.toStringAsFixed(2)
                                  : '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(labelText: '備考'),
                      ),
                      ElevatedButton(
                        onPressed: _addRecord,
                        child: const Text('記録を追加'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('health_records')
                        .orderBy('date', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final records = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return HealthRecord(
                          (data['date'] as Timestamp).toDate(),
                          data['distance'],
                          data['note'] ?? '備考なし',
                        );
                      }).toList();
                      return SfCartesianChart(
                        zoomPanBehavior: _zoomPanBehavior,
                        tooltipBehavior: _tooltipBehavior,
                        primaryXAxis: const DateTimeAxis(),
                        series: [
                          LineSeries<HealthRecord, DateTime>(
                            dataSource: records,
                            xValueMapper: (data, _) => data.date,
                            yValueMapper: (data, _) => data.distance,
                            dataLabelMapper: (data, _) => data.note,
                            enableTooltip: true,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
