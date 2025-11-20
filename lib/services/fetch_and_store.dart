import 'package:hamster_project/services/switchbot_service.dart';
import 'package:hamster_project/services/switchbot_repo.dart';

/// 選択済みの温湿度計から1回読み取り→Firestoreへ保存
Future<void> fetchAndStoreOnce() async {
  final repo = SwitchBotRepo();
  final meterId = await repo.getSelectedMeterId();
  if (meterId == null) {
    throw StateError('温湿度計が未選択です（FuncBで長押し保存してください）');
  }
  final reading = await SwitchBotService().readMeterOnce(meterId);
  await repo.addReading(reading);
}
