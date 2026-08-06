import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/freelancer_service_model.dart';
import 'freelancer_service_repository.dart';

class FreelancerServiceRepositoryImpl implements FreelancerServiceRepository {
  const FreelancerServiceRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _servicesRef =>
      _firestore.collection('freelancerServices');

  @override
  Future<String> createService(FreelancerServiceModel service) async {
    try {
      final doc = service.serviceId.trim().isEmpty
          ? _servicesRef.doc()
          : _servicesRef.doc(service.serviceId);
      final now = DateTime.now();
      final status = FreelancerServiceStatus.normalize(service.status);
      final payload = service
          .copyWith(
            serviceId: doc.id,
            status: status,
            isPublished: status == FreelancerServiceStatus.published,
            createdAt: now,
            updatedAt: now,
            publishedAt: status == FreelancerServiceStatus.published
                ? now
                : null,
            clearPublishedAt: status != FreelancerServiceStatus.published,
          )
          .toJson();
      await doc.set(payload);
      return doc.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create service: ${e.toString()}');
    }
  }

  @override
  Future<void> updateService(FreelancerServiceModel service) async {
    try {
      final status = FreelancerServiceStatus.normalize(service.status);
      final isPublished = status == FreelancerServiceStatus.published;
      final payload = service
          .copyWith(
            status: status,
            isPublished: isPublished,
            updatedAt: DateTime.now(),
            publishedAt: isPublished ? service.publishedAt : null,
            clearPublishedAt: !isPublished,
          )
          .toJson();
      if (!isPublished) {
        payload.remove('publishedAt');
      }
      await _servicesRef
          .doc(service.serviceId)
          .set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update service: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteService({
    required String serviceId,
    required String freelancerId,
  }) async {
    try {
      final doc = await _servicesRef.doc(serviceId).get();
      final service = _serviceFromDoc(doc);
      _assertOwner(service, freelancerId);
      await _servicesRef.doc(serviceId).delete();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to delete service: ${e.toString()}');
    }
  }

  @override
  Future<String> duplicateService({
    required String serviceId,
    required String freelancerId,
  }) async {
    try {
      final doc = await _servicesRef.doc(serviceId).get();
      final service = _serviceFromDoc(doc);
      _assertOwner(service, freelancerId);
      final now = DateTime.now();
      final duplicateDoc = _servicesRef.doc();
      final duplicate = service.copyWith(
        serviceId: duplicateDoc.id,
        title: '${service.title} Copy',
        status: FreelancerServiceStatus.draft,
        isPublished: false,
        createdAt: now,
        updatedAt: now,
        publishedAt: null,
        clearPublishedAt: true,
        viewCount: 0,
        inquiryCount: 0,
      );
      await duplicateDoc.set(duplicate.toJson()..remove('publishedAt'));
      return duplicateDoc.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to duplicate service: ${e.toString()}');
    }
  }

  @override
  Future<void> publishService({
    required String serviceId,
    required String freelancerId,
  }) async {
    try {
      final doc = await _servicesRef.doc(serviceId).get();
      final service = _serviceFromDoc(doc);
      _assertOwner(service, freelancerId);
      final now = DateTime.now();
      await _servicesRef.doc(serviceId).set({
        'status': FreelancerServiceStatus.published,
        'isPublished': true,
        'updatedAt': Timestamp.fromDate(now),
        'publishedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to publish service: ${e.toString()}');
    }
  }

  @override
  Future<void> unpublishService({
    required String serviceId,
    required String freelancerId,
  }) async {
    try {
      final doc = await _servicesRef.doc(serviceId).get();
      final service = _serviceFromDoc(doc);
      _assertOwner(service, freelancerId);
      final now = DateTime.now();
      await _servicesRef.doc(serviceId).set({
        'status': FreelancerServiceStatus.hidden,
        'isPublished': false,
        'updatedAt': Timestamp.fromDate(now),
        'publishedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } on FirestoreException {
      rethrow;
    } catch (e) {
      throw FirestoreException('Failed to unpublish service: ${e.toString()}');
    }
  }

  @override
  Stream<List<FreelancerServiceModel>> watchMyServices(String freelancerId) {
    return _servicesRef
        .where('freelancerId', isEqualTo: freelancerId)
        .snapshots()
        .map((snapshot) {
          final services = snapshot.docs
              .map(FreelancerServiceModel.fromFirestore)
              .toList();
          services.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return services;
        });
  }

  @override
  Stream<List<FreelancerServiceModel>> watchPublishedServices() {
    return _servicesRef.where('isPublished', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final services = snapshot.docs
          .map(FreelancerServiceModel.fromFirestore)
          .where((service) => service.isLive)
          .toList();
      services.sort(
        (a, b) => (b.publishedAt ?? b.updatedAt).compareTo(
          a.publishedAt ?? a.updatedAt,
        ),
      );
      return services;
    });
  }

  @override
  Stream<FreelancerServiceModel?> watchService(String serviceId) {
    return _servicesRef.doc(serviceId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return FreelancerServiceModel.fromFirestore(doc);
    });
  }

  FreelancerServiceModel _serviceFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) {
      throw const FirestoreException('Service not found.');
    }
    return FreelancerServiceModel.fromFirestore(doc);
  }

  void _assertOwner(FreelancerServiceModel service, String freelancerId) {
    if (service.freelancerId != freelancerId) {
      throw const FirestoreException('You can only manage your own services.');
    }
  }
}
