import 'package:hamster_project/models/ai_advisor_context.dart';
import 'package:hamster_project/services/health_assessment_repo.dart';

class AiAdvisorContextService {
  final HealthAssessmentRepo _healthAssessmentRepo;

  AiAdvisorContextService({
    HealthAssessmentRepo? healthAssessmentRepo,
  }) : _healthAssessmentRepo = healthAssessmentRepo ?? HealthAssessmentRepo();

  Future<AiAdvisorContext?> fetchLatest() async {
    final assessment = await _healthAssessmentRepo.fetchLatest();

    if (assessment == null || !assessment.hasMeaningfulAssessment) {
      return null;
    }

    return AiAdvisorContext.fromHealthAssessment(assessment);
  }

  Stream<AiAdvisorContext?> watchLatest() {
    return _healthAssessmentRepo.watchLatest().map(
      (assessment) {
        if (assessment == null || !assessment.hasMeaningfulAssessment) {
          return null;
        }

        return AiAdvisorContext.fromHealthAssessment(
          assessment,
        );
      },
    );
  }
}
