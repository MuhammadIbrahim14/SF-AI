import '../models/job_model.dart';

abstract class JobRepository {
  Future<void> createJob(JobModel job);
  Future<void> updateJob(JobModel job);
  Future<void> deleteJob(String jobId);
  Future<JobModel?> getJob(String jobId);
  Stream<List<JobModel>> streamAllJobs();
  Stream<List<JobModel>> streamJobsByCompany(String companyId);
}
