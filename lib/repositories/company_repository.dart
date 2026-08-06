import '../models/company_model.dart';

abstract class CompanyRepository {
  Future<void> createCompany(CompanyModel company);
  Future<CompanyModel?> getCompany(String userId);
  Stream<CompanyModel?> companyStream(String userId);
  Future<void> updateCompany({
    required String userId,
    required Map<String, dynamic> data,
  });
}
