import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all projects (no user filtering)
  static Stream<List<Project>> getProjects(String userId) {
    print('🔍 FirestoreService: Loading all projects from projects collection');
    return _firestore
        .collection('projects')
        .snapshots()
        .map((snapshot) {
      print('🔍 FirestoreService: Found ${snapshot.docs.length} documents');
      final projects = snapshot.docs.map((doc) {
        print('🔍 FirestoreService: Processing doc ${doc.id} with data: ${doc.data()}');
        return Project.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      // Sort by createdAt in descending order in memory
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      print('🔍 FirestoreService: Returning ${projects.length} projects');
      return projects;
    });
  }

  // Add a new project (no user filtering)
  static Future<void> addProject(String userId, Project project) async {
    try {
      print('🔍 FirestoreService: Adding project to projects collection');
      print('📊 Project data to add: ${project.toFirestore()}');
      
      // Check if Firestore is initialized
      if (_firestore == null) {
        throw Exception('Firestore is not initialized');
      }
      
      // Add the document to Firestore
      final docRef = await _firestore
          .collection('projects')
          .add(project.toFirestore());
      
      print('✅ Project added successfully with document ID: ${docRef.id}');
    } catch (e) {
      print('❌ FirestoreService.addProject error: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error details: ${e.toString()}');
      
      // Re-throw with more context
      throw Exception('Failed to add project to Firestore: $e');
    }
  }

  // Update a project
  static Future<void> updateProject(String userId, Project project) async {
    await _firestore
        .collection('projects')
        .doc(project.id)
        .update(project.toFirestore());
  }

  // Delete a project (soft delete by setting isActive to false)
  static Future<void> deleteProject(String userId, String projectId) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .update({'isActive': false});
  }

  // Get a single project
  static Future<Project?> getProject(String userId, String projectId) async {
    final doc = await _firestore
        .collection('projects')
        .doc(projectId)
        .get();
    
    if (doc.exists) {
      return Project.fromFirestore(doc.data()!, doc.id);
    }
    return null;
  }

  // Create a sample project for testing
  static Future<void> createSampleProject(String userId) async {
    final sampleProject = Project(
      id: 'sample-project-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Sample Project',
      owner: 'your-github-username',
      repository: 'your-repo-name',
      description: 'A sample project for testing the dashboard',
      githubToken: 'your-github-token-here',
      createdAt: DateTime.now(),
      isActive: true,
    );

    await addProject(userId, sampleProject);
  }


} 