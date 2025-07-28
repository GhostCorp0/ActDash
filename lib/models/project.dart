import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  final String id;
  final String name;
  final String owner;
  final String repository;
  final String description;
  final String githubToken;
  final DateTime createdAt;
  final bool isActive;

  Project({
    required this.id,
    required this.name,
    required this.owner,
    required this.repository,
    required this.description,
    required this.githubToken,
    required this.createdAt,
    this.isActive = true,
  });

  factory Project.fromFirestore(Map<String, dynamic> data, String id) {
    return Project(
      id: id,
      name: data['name'] ?? '',
      owner: data['owner'] ?? '',
      repository: data['repository'] ?? '',
      description: data['description'] ?? '',
      githubToken: data['githubToken'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'owner': owner,
      'repository': repository,
      'description': description,
      'githubToken': githubToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  String get fullRepositoryName => '$owner/$repository';
} 