import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GitHubApiService {
  static const String _baseUrl = 'https://api.github.com';
  static const String _tokenKey = 'github_token';
  static const String _ownerKey = 'github_owner';
  static const String _repoKey = 'github_repo';

  // Get stored GitHub token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Store GitHub token
  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Get stored repository info
  static Future<Map<String, String?>> getRepositoryInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'owner': prefs.getString(_ownerKey),
      'repo': prefs.getString(_repoKey),
    };
  }

  // Store repository info
  static Future<void> setRepositoryInfo(String owner, String repo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerKey, owner);
    await prefs.setString(_repoKey, repo);
  }

  // Get headers for API requests
  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Accept': 'application/vnd.github.v3+json',
      'Authorization': token != null ? 'token $token' : '',
      'User-Agent': 'GitHub-Actions-Dashboard/1.0',
    };
  }

  // Get workflows for a repository
  static Future<List<Workflow>> getWorkflows() async {
    try {
      final repoInfo = await getRepositoryInfo();
      final owner = repoInfo['owner'];
      final repo = repoInfo['repo'];

      if (owner == null || repo == null) {
        throw Exception('Repository information not configured');
      }

      final headers = await _getHeaders();
      final url = '$_baseUrl/repos/$owner/$repo/actions/workflows';
      
      print('Fetching workflows from: $url');
      print('Headers: ${headers.keys}');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['workflows'] as List)
            .map((workflow) => Workflow.fromJson(workflow))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please check your GitHub token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Token may not have sufficient permissions');
      } else if (response.statusCode == 404) {
        throw Exception('Repository not found: Please check owner and repository name');
      } else {
        throw Exception('Failed to load workflows: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getWorkflows: $e');
      throw Exception('Error fetching workflows: $e');
    }
  }

  // Get workflow runs
  static Future<List<WorkflowRun>> getWorkflowRuns({
    String? workflowId,
    int perPage = 30,
  }) async {
    try {
      final repoInfo = await getRepositoryInfo();
      final owner = repoInfo['owner'];
      final repo = repoInfo['repo'];

      if (owner == null || repo == null) {
        throw Exception('Repository information not configured');
      }

      final headers = await _getHeaders();
      String url = '$_baseUrl/repos/$owner/$repo/actions/runs?per_page=$perPage';
      
      if (workflowId != null) {
        url = '$_baseUrl/repos/$owner/$repo/actions/workflows/$workflowId/runs?per_page=$perPage';
      }

      print('Fetching workflow runs from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Response status: ${response.statusCode}');
      print('=== COMPLETE WORKFLOW RUNS API RESPONSE ===');
      print('Response body: ${response.body}');
      print('=== END WORKFLOW RUNS API RESPONSE ===');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final workflowRuns = data['workflow_runs'] as List?;
        
        if (workflowRuns == null) {
          print('No workflow_runs found in response');
          return [];
        }
        
        return workflowRuns.map((run) {
          try {
            print('=== DETAILED WORKFLOW RUN DATA ===');
            print('Workflow Run ID: ${run['id']}');
            print('Complete run data: $run');
            print('=== END DETAILED WORKFLOW RUN DATA ===');
            
            // Calculate duration if we have start and end times
            String duration = 'Unknown';
            if (run['run_started_at'] != null && run['completed_at'] != null) {
              try {
                final startTime = DateTime.parse(run['run_started_at']);
                final endTime = DateTime.parse(run['completed_at']);
                final durationInSeconds = endTime.difference(startTime).inSeconds;
                duration = '${durationInSeconds}s';
                print('Calculated duration: $duration');
              } catch (e) {
                print('Error calculating duration: $e');
              }
            } else {
              print('Missing timing data - run_started_at: ${run['run_started_at']}, completed_at: ${run['completed_at']}');
            }
            
            return WorkflowRun.fromJson(run);
          } catch (e) {
            print('Error parsing workflow run: $e');
            print('Run data: $run');
            // Return a default run to prevent the entire list from failing
            return WorkflowRun(
              id: run['id'] ?? 0,
              name: run['name'] ?? 'Unknown Workflow',
              headBranch: run['head_branch'] ?? 'unknown',
              headSha: run['head_sha'] ?? '',
              runNumber: run['run_number']?.toString() ?? '0',
              event: run['event'] ?? 'unknown',
              status: run['status'] ?? 'unknown',
              conclusion: run['conclusion'] ?? '',
              workflowId: run['workflow_id'] ?? 0,
              workflowName: run['workflow_name'] ?? 'Unknown Workflow',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              runStartedAt: null,
              completedAt: null,
              actor: run['actor']?['login'] ?? 'unknown',
              triggeringActor: run['triggering_actor']?['login'] ?? 'unknown',
              runAttempt: run['run_attempt']?.toString() ?? '1',
              runStartedAtString: run['run_started_at'] ?? '',
              stepsCount: run['steps_count'] ?? 0,
              completedStepsCount: run['completed_steps_count'] ?? 0,
              headCommit: run['head_commit']?['message'] ?? 'No commit message',
            );
          }
        }).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please check your GitHub token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Token may not have sufficient permissions');
      } else if (response.statusCode == 404) {
        throw Exception('Repository not found: Please check owner and repository name');
      } else {
        throw Exception('Failed to load workflow runs: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getWorkflowRuns: $e');
      throw Exception('Error fetching workflow runs: $e');
    }
  }

  // Get repository statistics
  static Future<RepositoryStats> getRepositoryStats() async {
    try {
      final repoInfo = await getRepositoryInfo();
      final owner = repoInfo['owner'];
      final repo = repoInfo['repo'];

      if (owner == null || repo == null) {
        throw Exception('Repository information not configured');
      }

      final headers = await _getHeaders();
      final url = '$_baseUrl/repos/$owner/$repo';
      
      print('Fetching repository stats from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return RepositoryStats.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please check your GitHub token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Token may not have sufficient permissions');
      } else if (response.statusCode == 404) {
        throw Exception('Repository not found: Please check owner and repository name');
      } else {
        throw Exception('Failed to load repository stats: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getRepositoryStats: $e');
      throw Exception('Error fetching repository stats: $e');
    }
  }

  // Get workflow run details
  static Future<WorkflowRunDetails> getWorkflowRunDetails(int runId) async {
    try {
      final repoInfo = await getRepositoryInfo();
      final owner = repoInfo['owner'];
      final repo = repoInfo['repo'];

      if (owner == null || repo == null) {
        throw Exception('Repository information not configured');
      }

      final headers = await _getHeaders();
      final url = '$_baseUrl/repos/$owner/$repo/actions/runs/$runId';
      
      print('Fetching workflow run details from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WorkflowRunDetails.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please check your GitHub token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Token may not have sufficient permissions');
      } else if (response.statusCode == 404) {
        throw Exception('Workflow run not found');
      } else {
        throw Exception('Failed to load workflow run details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getWorkflowRunDetails: $e');
      throw Exception('Error fetching workflow run details: $e');
    }
  }

  // Get jobs for a workflow run
  static Future<List<Job>> getJobs(int runId) async {
    try {
      final repoInfo = await getRepositoryInfo();
      final owner = repoInfo['owner'];
      final repo = repoInfo['repo'];

      if (owner == null || repo == null) {
        throw Exception('Repository information not configured');
      }

      final headers = await _getHeaders();
      final url = '$_baseUrl/repos/$owner/$repo/actions/runs/$runId/jobs';
      
      print('Fetching jobs from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['jobs'] as List)
            .map((job) => Job.fromJson(job))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please check your GitHub token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Token may not have sufficient permissions');
      } else if (response.statusCode == 404) {
        throw Exception('Workflow run not found');
      } else {
        throw Exception('Failed to load jobs: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getJobs: $e');
      throw Exception('Error fetching jobs: $e');
    }
  }

  // Test connection with better error handling
  static Future<bool> testConnection() async {
    try {
      final repoInfo = await getRepositoryInfo();
      final owner = repoInfo['owner'];
      final repo = repoInfo['repo'];
      final token = await getToken();

      if (token == null) {
        throw Exception('GitHub token not configured');
      }

      if (owner == null || repo == null) {
        throw Exception('Repository information not configured');
      }

      // Test with a simple API call
      final headers = await _getHeaders();
      final url = '$_baseUrl/repos/$owner/$repo';
      
      print('Testing connection to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Test response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid GitHub token');
      } else if (response.statusCode == 403) {
        throw Exception('Token lacks required permissions');
      } else if (response.statusCode == 404) {
        throw Exception('Repository not found: $owner/$repo');
      } else {
        throw Exception('Connection failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Connection test failed: $e');
      throw Exception('Connection test failed: $e');
    }
  }
}

// Data Models
class Workflow {
  final int id;
  final String name;
  final String path;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;

  Workflow({
    required this.id,
    required this.name,
    required this.path,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      state: json['state'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class WorkflowRun {
  final int id;
  final String name;
  final String headBranch;
  final String headSha;
  final String runNumber;
  final String event;
  final String status;
  final String conclusion;
  final int workflowId;
  final String workflowName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? runStartedAt;
  final DateTime? completedAt;
  final String actor;
  final String triggeringActor;
  final String runAttempt;
  final String runStartedAtString;
  final int stepsCount;
  final int completedStepsCount;
  final String headCommit;

  WorkflowRun({
    required this.id,
    required this.name,
    required this.headBranch,
    required this.headSha,
    required this.runNumber,
    required this.event,
    required this.status,
    required this.conclusion,
    required this.workflowId,
    required this.workflowName,
    required this.createdAt,
    required this.updatedAt,
    this.runStartedAt,
    this.completedAt,
    required this.actor,
    required this.triggeringActor,
    required this.runAttempt,
    required this.runStartedAtString,
    required this.stepsCount,
    required this.completedStepsCount,
    required this.headCommit,
  });

  factory WorkflowRun.fromJson(Map<String, dynamic> json) {
    print('=== WORKFLOW RUN FROM JSON DEBUG ===');
    print('Parsing workflow run with ID: ${json['id']}');
    print('Raw JSON keys: ${json.keys.toList()}');
    print('run_started_at raw value: ${json['run_started_at']}');
    print('completed_at raw value: ${json['completed_at']}');
    print('status: ${json['status']}');
    print('conclusion: ${json['conclusion']}');
    
    DateTime parseDateTime(String? dateString) {
      if (dateString == null) {
        print('Date string is null, using current time');
        return DateTime.now();
      }
      try {
        final parsed = DateTime.parse(dateString);
        print('Successfully parsed date: $dateString -> $parsed');
        return parsed;
      } catch (e) {
        print('Error parsing date: $dateString - $e');
        return DateTime.now();
      }
    }

    final runStartedAt = json['run_started_at'] != null 
        ? parseDateTime(json['run_started_at']) 
        : null;
    final completedAt = json['completed_at'] != null 
        ? parseDateTime(json['completed_at']) 
        : null;
    
    print('Parsed runStartedAt: $runStartedAt');
    print('Parsed completedAt: $completedAt');
    print('=== END WORKFLOW RUN FROM JSON DEBUG ===');

    return WorkflowRun(
      id: json['id'],
      name: json['name'] ?? 'Unknown Workflow',
      headBranch: json['head_branch'] ?? 'unknown',
      headSha: json['head_sha'] ?? '',
      runNumber: json['run_number']?.toString() ?? '0',
      event: json['event'] ?? 'unknown',
      status: json['status'] ?? 'unknown',
      conclusion: json['conclusion'] ?? '',
      workflowId: json['workflow_id'] ?? 0,
      workflowName: json['workflow_name'] ?? 'Unknown Workflow',
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
      runStartedAt: runStartedAt,
      completedAt: completedAt,
      actor: json['actor']?['login'] ?? 'unknown',
      triggeringActor: json['triggering_actor']?['login'] ?? 'unknown',
      runAttempt: json['run_attempt']?.toString() ?? '1',
      runStartedAtString: json['run_started_at'] ?? '',
      stepsCount: json['steps_count'] ?? 0,
      completedStepsCount: json['completed_steps_count'] ?? 0,
      headCommit: json['head_commit']?['message'] ?? 'No commit message',
    );
  }

  Duration? get duration {
    print('=== DURATION CALCULATION DEBUG ===');
    print('Workflow Run ID: $id');
    print('Name: $name');
    print('runStartedAt: $runStartedAt');
    print('completedAt: $completedAt');
    print('Status: $status');
    print('Conclusion: $conclusion');
    print('Updated At: $updatedAt');
    
    // For completed runs, use updatedAt as the completion time
    DateTime? endTime = completedAt;
    if (endTime == null && status == 'completed' && conclusion != null) {
      print('Using updatedAt as completion time for completed run');
      endTime = updatedAt;
    }
    
    if (runStartedAt != null && endTime != null) {
      final duration = endTime.difference(runStartedAt!);
      print('Calculated duration: ${duration.inSeconds} seconds');
      print('Duration string: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
      print('=== END DURATION DEBUG ===');
      return duration;
    } else {
      print('Missing timing data - cannot calculate duration');
      print('runStartedAt is null: ${runStartedAt == null}');
      print('endTime is null: ${endTime == null}');
      print('=== END DURATION DEBUG ===');
      return null;
    }
  }

  String get durationString {
    print('=== DURATION STRING DEBUG ===');
    print('Workflow Run ID: $id');
    
    final dur = duration;
    if (dur == null) {
      if (status == 'completed') {
        print('Duration is null but run is completed, returning "Unknown"');
        print('=== END DURATION STRING DEBUG ===');
        return 'Unknown';
      } else {
        print('Duration is null, returning "Running..."');
        print('=== END DURATION STRING DEBUG ===');
        return 'Running...';
      }
    }
    
    final minutes = dur.inMinutes;
    final seconds = dur.inSeconds % 60;
    final result = '${minutes}m ${seconds}s';
    print('Duration string result: $result');
    print('=== END DURATION STRING DEBUG ===');
    return result;
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

class WorkflowRunDetails extends WorkflowRun {
  final String url;
  final String htmlUrl;
  final String jobsUrl;
  final String logsUrl;
  final String checkSuiteUrl;
  final String artifactsUrl;
  final String cancelUrl;
  final String rerunUrl;
  final String previousAttemptUrl;
  final String workflowUrl;
  final String headCommitUrl;
  final String repositoryUrl;

  WorkflowRunDetails({
    required super.id,
    required super.name,
    required super.headBranch,
    required super.headSha,
    required super.runNumber,
    required super.event,
    required super.status,
    required super.conclusion,
    required super.workflowId,
    required super.workflowName,
    required super.createdAt,
    required super.updatedAt,
    super.runStartedAt,
    super.completedAt,
    required super.actor,
    required super.triggeringActor,
    required super.runAttempt,
    required super.runStartedAtString,
    required super.stepsCount,
    required super.completedStepsCount,
    required super.headCommit,
    required this.url,
    required this.htmlUrl,
    required this.jobsUrl,
    required this.logsUrl,
    required this.checkSuiteUrl,
    required this.artifactsUrl,
    required this.cancelUrl,
    required this.rerunUrl,
    required this.previousAttemptUrl,
    required this.workflowUrl,
    required this.headCommitUrl,
    required this.repositoryUrl,
  });

  factory WorkflowRunDetails.fromJson(Map<String, dynamic> json) {
    return WorkflowRunDetails(
      id: json['id'],
      name: json['name'] ?? 'Unknown Workflow',
      headBranch: json['head_branch'] ?? 'unknown',
      headSha: json['head_sha'] ?? '',
      runNumber: json['run_number']?.toString() ?? '0',
      event: json['event'] ?? 'unknown',
      status: json['status'] ?? 'unknown',
      conclusion: json['conclusion'] ?? '',
      workflowId: json['workflow_id'] ?? 0,
      workflowName: json['workflow_name'] ?? 'Unknown Workflow',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      runStartedAt: json['run_started_at'] != null 
          ? DateTime.parse(json['run_started_at']) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      actor: json['actor']?['login'] ?? 'unknown',
      triggeringActor: json['triggering_actor']?['login'] ?? 'unknown',
      runAttempt: json['run_attempt']?.toString() ?? '1',
      runStartedAtString: json['run_started_at'] ?? '',
      stepsCount: json['steps_count'] ?? 0,
      completedStepsCount: json['completed_steps_count'] ?? 0,
      headCommit: json['head_commit']?['message'] ?? 'No commit message',
      url: json['url'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      jobsUrl: json['jobs_url'] ?? '',
      logsUrl: json['logs_url'] ?? '',
      checkSuiteUrl: json['check_suite_url'] ?? '',
      artifactsUrl: json['artifacts_url'] ?? '',
      cancelUrl: json['cancel_url'] ?? '',
      rerunUrl: json['rerun_url'] ?? '',
      previousAttemptUrl: json['previous_attempt_url'] ?? '',
      workflowUrl: json['workflow_url'] ?? '',
      headCommitUrl: json['head_commit']?['url'] ?? '',
      repositoryUrl: json['repository']?['url'] ?? '',
    );
  }
}

class Job {
  final int id;
  final int runId;
  final String runUrl;
  final String runAttempt;
  final String nodeId;
  final String headSha;
  final String url;
  final String htmlUrl;
  final String status;
  final String conclusion;
  final DateTime createdAt;
  final DateTime startedAt;
  final DateTime completedAt;
  final String name;
  final List<Step> steps;
  final String checkRunUrl;
  final List<String> labels;
  final String runnerId;
  final String runnerName;
  final String runnerGroupId;
  final String runnerGroupName;
  final String workflowName;
  final String headBranch;

  Job({
    required this.id,
    required this.runId,
    required this.runUrl,
    required this.runAttempt,
    required this.nodeId,
    required this.headSha,
    required this.url,
    required this.htmlUrl,
    required this.status,
    required this.conclusion,
    required this.createdAt,
    required this.startedAt,
    required this.completedAt,
    required this.name,
    required this.steps,
    required this.checkRunUrl,
    required this.labels,
    required this.runnerId,
    required this.runnerName,
    required this.runnerGroupId,
    required this.runnerGroupName,
    required this.workflowName,
    required this.headBranch,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      runId: json['run_id'],
      runUrl: json['run_url'] ?? '',
      runAttempt: json['run_attempt']?.toString() ?? '1',
      nodeId: json['node_id'] ?? '',
      headSha: json['head_sha'] ?? '',
      url: json['url'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      status: json['status'] ?? 'unknown',
      conclusion: json['conclusion'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      startedAt: DateTime.parse(json['started_at']),
      completedAt: DateTime.parse(json['completed_at']),
      name: json['name'] ?? 'Unknown Job',
      steps: (json['steps'] as List?)
          ?.map((step) => Step.fromJson(step))
          .toList() ?? [],
      checkRunUrl: json['check_run_url'] ?? '',
      labels: List<String>.from(json['labels'] ?? []),
      runnerId: json['runner_id']?.toString() ?? '',
      runnerName: json['runner_name'] ?? '',
      runnerGroupId: json['runner_group_id']?.toString() ?? '',
      runnerGroupName: json['runner_group_name'] ?? '',
      workflowName: json['workflow_name'] ?? 'Unknown Workflow',
      headBranch: json['head_branch'] ?? 'unknown',
    );
  }

  Duration get duration {
    return completedAt.difference(startedAt);
  }

  String get durationString {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

class Step {
  final String name;
  final String status;
  final String conclusion;
  final int number;
  final DateTime startedAt;
  final DateTime completedAt;

  Step({
    required this.name,
    required this.status,
    required this.conclusion,
    required this.number,
    required this.startedAt,
    required this.completedAt,
  });

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      name: json['name'] ?? 'Unknown Step',
      status: json['status'] ?? 'unknown',
      conclusion: json['conclusion'] ?? '',
      number: json['number'] ?? 0,
      startedAt: DateTime.parse(json['started_at']),
      completedAt: DateTime.parse(json['completed_at']),
    );
  }

  Duration get duration {
    return completedAt.difference(startedAt);
  }
}

class RepositoryStats {
  final String name;
  final String fullName;
  final String description;
  final int stargazersCount;
  final int watchersCount;
  final int forksCount;
  final int openIssuesCount;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime pushedAt;
  final int size;
  final bool hasIssues;
  final bool hasProjects;
  final bool hasDownloads;
  final bool hasWiki;
  final bool hasPages;
  final bool hasDiscussions;
  final int forks;
  final int openIssues;
  final int watchers;
  final String defaultBranch;
  final int networkCount;
  final int subscribersCount;

  RepositoryStats({
    required this.name,
    required this.fullName,
    required this.description,
    required this.stargazersCount,
    required this.watchersCount,
    required this.forksCount,
    required this.openIssuesCount,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    required this.pushedAt,
    required this.size,
    required this.hasIssues,
    required this.hasProjects,
    required this.hasDownloads,
    required this.hasWiki,
    required this.hasPages,
    required this.hasDiscussions,
    required this.forks,
    required this.openIssues,
    required this.watchers,
    required this.defaultBranch,
    required this.networkCount,
    required this.subscribersCount,
  });

  factory RepositoryStats.fromJson(Map<String, dynamic> json) {
    return RepositoryStats(
      name: json['name'] ?? 'Unknown Repository',
      fullName: json['full_name'] ?? 'unknown/unknown',
      description: json['description'] ?? '',
      stargazersCount: json['stargazers_count'] ?? 0,
      watchersCount: json['watchers_count'] ?? 0,
      forksCount: json['forks_count'] ?? 0,
      openIssuesCount: json['open_issues_count'] ?? 0,
      language: json['language'] ?? 'Unknown',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      pushedAt: DateTime.parse(json['pushed_at']),
      size: json['size'] ?? 0,
      hasIssues: json['has_issues'] ?? false,
      hasProjects: json['has_projects'] ?? false,
      hasDownloads: json['has_downloads'] ?? false,
      hasWiki: json['has_wiki'] ?? false,
      hasPages: json['has_pages'] ?? false,
      hasDiscussions: json['has_discussions'] ?? false,
      forks: json['forks'] ?? 0,
      openIssues: json['open_issues'] ?? 0,
      watchers: json['watchers'] ?? 0,
      defaultBranch: json['default_branch'] ?? 'main',
      networkCount: json['network_count'] ?? 0,
      subscribersCount: json['subscribers_count'] ?? 0,
    );
  }
} 