import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'services/github_api_service.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const GitHubActionsDashboard());
}

class GitHubActionsDashboard extends StatelessWidget {
  const GitHubActionsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Actions Analytics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F2937),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(
                right: BorderSide(color: Color(0xFF334155), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.rocket_launch,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'GitHub Actions',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF334155)),
                // Navigation
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                      _buildNavItem(Icons.analytics, 'Analytics', 1),
                      _buildNavItem(Icons.history, 'Build History', 2),
                      _buildNavItem(Icons.settings, 'Settings', 3),
                    ],
                  ),
                ),
                // User info
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF3B82F6),
                        child: Text(
                          'AS',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aman Singh',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Developer',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : null,
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardView();
      case 1:
        return const AnalyticsView();
      case 2:
        return const BuildHistoryView();
      case 3:
        return const SettingsScreen();
      default:
        return const DashboardView();
    }
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  List<WorkflowRun> _workflowRuns = [];
  RepositoryStats? _repositoryStats;
  bool _isLoading = true;
  String? _error;
  bool _isDemoMode = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if GitHub is configured
      final token = await GitHubApiService.getToken();
      final repoInfo = await GitHubApiService.getRepositoryInfo();

      if (token == null || repoInfo['owner'] == null || repoInfo['repo'] == null) {
        // Show demo data if GitHub is not configured
        setState(() {
          _isDemoMode = true;
          _workflowRuns = _getDemoWorkflowRuns();
          _repositoryStats = _getDemoRepositoryStats();
          _isLoading = false;
        });
        return;
      }

      // Load data in parallel
      final futures = await Future.wait([
        GitHubApiService.getWorkflowRuns(perPage: 50),
        GitHubApiService.getRepositoryStats(),
      ]);

      final workflowRuns = futures[0] as List<WorkflowRun>;
      final repositoryStats = futures[1] as RepositoryStats;
      
      print('=== LOADED WORKFLOW RUNS ===');
      for (var run in workflowRuns) {
        print('Run ID: ${run.id}');
        print('  Name: ${run.name}');
        print('  Status: ${run.status}');
        print('  Conclusion: ${run.conclusion}');
        print('  Run Started At: ${run.runStartedAt}');
        print('  Completed At: ${run.completedAt}');
        print('  Duration: ${run.duration}');
        print('  Duration String: ${run.durationString}');
        print('  Time Ago: ${run.timeAgo}');
        print('---');
      }
      print('=== END WORKFLOW RUNS ===');
      
      setState(() {
        _workflowRuns = workflowRuns;
        _repositoryStats = repositoryStats;
        _isLoading = false;
        _isDemoMode = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading data: $e';
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Start auto-refresh timer
  void _startAutoRefresh() {
    _refreshTimer?.cancel(); // Cancel any existing timer
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      print('🔄 Auto-refreshing dashboard data...');
      _loadData();
    });
  }

  // Stop auto-refresh timer
  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // Helper function to get month name
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  // Demo data for when GitHub is not configured
  List<WorkflowRun> _getDemoWorkflowRuns() {
    final now = DateTime.now();
    return [
      WorkflowRun(
        id: 1,
        name: 'CI/CD Pipeline',
        headBranch: 'main',
        headSha: 'abc123',
        runNumber: '1',
        event: 'push',
        status: 'completed',
        conclusion: 'success',
        workflowId: 1,
        workflowName: 'CI/CD Pipeline',
        createdAt: now.subtract(const Duration(minutes: 5)),
        updatedAt: now.subtract(const Duration(minutes: 2)),
        runStartedAt: now.subtract(const Duration(minutes: 4)),
        completedAt: now.subtract(const Duration(minutes: 2)),
        actor: 'demo-user',
        triggeringActor: 'demo-user',
        runAttempt: '1',
        runStartedAtString: now.subtract(const Duration(minutes: 4)).toIso8601String(),
        stepsCount: 8,
        completedStepsCount: 8,
        headCommit: 'Add new feature implementation',
      ),
      WorkflowRun(
        id: 2,
        name: 'Test Suite',
        headBranch: 'feature/auth',
        headSha: 'def456',
        runNumber: '2',
        event: 'pull_request',
        status: 'completed',
        conclusion: 'failure',
        workflowId: 2,
        workflowName: 'Test Suite',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
        runStartedAt: now.subtract(const Duration(hours: 1, minutes: 45)),
        completedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
        actor: 'demo-user',
        triggeringActor: 'demo-user',
        runAttempt: '1',
        runStartedAtString: now.subtract(const Duration(hours: 1, minutes: 45)).toIso8601String(),
        stepsCount: 12,
        completedStepsCount: 10,
        headCommit: 'Fix authentication bug',
      ),
      WorkflowRun(
        id: 3,
        name: 'Deploy to Production',
        headBranch: 'main',
        headSha: 'ghi789',
        runNumber: '3',
        event: 'push',
        status: 'completed',
        conclusion: 'success',
        workflowId: 3,
        workflowName: 'Deploy to Production',
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 3, minutes: 45)),
        runStartedAt: now.subtract(const Duration(hours: 3, minutes: 50)),
        completedAt: now.subtract(const Duration(hours: 3, minutes: 45)),
        actor: 'demo-user',
        triggeringActor: 'demo-user',
        runAttempt: '1',
        runStartedAtString: now.subtract(const Duration(hours: 3, minutes: 50)).toIso8601String(),
        stepsCount: 15,
        completedStepsCount: 15,
        headCommit: 'Release v1.2.0',
      ),
      WorkflowRun(
        id: 4,
        name: 'Security Scan',
        headBranch: 'develop',
        headSha: 'jkl012',
        runNumber: '4',
        event: 'push',
        status: 'completed',
        conclusion: 'success',
        workflowId: 4,
        workflowName: 'Security Scan',
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 5, minutes: 30)),
        runStartedAt: now.subtract(const Duration(hours: 5, minutes: 35)),
        completedAt: now.subtract(const Duration(hours: 5, minutes: 30)),
        actor: 'demo-user',
        triggeringActor: 'demo-user',
        runAttempt: '1',
        runStartedAtString: now.subtract(const Duration(hours: 5, minutes: 35)).toIso8601String(),
        stepsCount: 6,
        completedStepsCount: 6,
        headCommit: 'Update dependencies',
      ),
      WorkflowRun(
        id: 5,
        name: 'Build and Test',
        headBranch: 'feature/ui',
        headSha: 'mno345',
        runNumber: '5',
        event: 'pull_request',
        status: 'completed',
        conclusion: 'success',
        workflowId: 5,
        workflowName: 'Build and Test',
        createdAt: now.subtract(const Duration(hours: 8)),
        updatedAt: now.subtract(const Duration(hours: 7, minutes: 15)),
        runStartedAt: now.subtract(const Duration(hours: 7, minutes: 20)),
        completedAt: now.subtract(const Duration(hours: 7, minutes: 15)),
        actor: 'demo-user',
        triggeringActor: 'demo-user',
        runAttempt: '1',
        runStartedAtString: now.subtract(const Duration(hours: 7, minutes: 20)).toIso8601String(),
        stepsCount: 10,
        completedStepsCount: 10,
        headCommit: 'Improve UI components',
      ),
    ];
  }

  RepositoryStats _getDemoRepositoryStats() {
    return RepositoryStats(
      name: 'demo-repo',
      fullName: 'demo-user/demo-repo',
      description: 'A demo repository for GitHub Actions Dashboard',
      stargazersCount: 42,
      watchersCount: 8,
      forksCount: 12,
      openIssuesCount: 5,
      language: 'Dart',
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      pushedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      size: 1024,
      hasIssues: true,
      hasProjects: true,
      hasDownloads: true,
      hasWiki: true,
      hasPages: false,
      hasDiscussions: false,
      forks: 12,
      openIssues: 5,
      watchers: 8,
      defaultBranch: 'main',
      networkCount: 15,
      subscribersCount: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading GitHub Actions data...',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Demo mode banner
        if (_isDemoMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Demo Mode: Showing sample data. Configure GitHub in Settings to see your real data.',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to settings
                    // You can implement navigation here
                  },
                  child: Text(
                    'Configure',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Monitor your GitHub Actions performance and analytics',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Manual refresh button
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: IconButton(
                            onPressed: () {
                              print('🔄 Manual refresh triggered');
                              _loadData();
                            },
                            icon: const Icon(
                              Icons.refresh,
                              color: Color(0xFF3B82F6),
                              size: 20,
                            ),
                            tooltip: 'Refresh data',
                          ),
                        ),
                        // Status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle, color: Colors.white, size: 8),
                              const SizedBox(width: 8),
                              Text(
                                'All Systems Operational',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Stats Cards
                _buildStatsCards(),
                const SizedBox(height: 32),
                
                // Charts Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildBuildTrendsChart(),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildSuccessRateChart(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Recent Builds
                _buildRecentBuilds(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    final totalBuilds = _workflowRuns.length;
    final successfulBuilds = _workflowRuns.where((run) => run.conclusion == 'success').length;
    final failedBuilds = _workflowRuns.where((run) => run.conclusion == 'failure').length;
    final successRate = totalBuilds > 0 ? (successfulBuilds / totalBuilds) * 100 : 0.0;
    
    // Calculate average duration
    final completedRuns = _workflowRuns.where((run) => run.duration != null).toList();
    final avgDuration = completedRuns.isNotEmpty 
        ? completedRuns.map((run) => run.duration!.inSeconds).reduce((a, b) => a + b) / completedRuns.length
        : 0;
    
    final avgMinutes = avgDuration ~/ 60;
    final avgSeconds = avgDuration % 60;

    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Builds', totalBuilds.toString(), Icons.build, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Success Rate', '${successRate.toStringAsFixed(1)}%', Icons.check_circle, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Avg Duration', '${avgMinutes}m ${avgSeconds}s', Icons.timer, Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Failed Builds', failedBuilds.toString(), Icons.error, Colors.red)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildTrendsChart() {
    // Show current month with all days
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Get the first day of current month
    final firstDayOfMonth = DateTime(currentYear, currentMonth, 1);
    
    // Get the last day of current month
    final lastDayOfMonth = DateTime(currentYear, currentMonth + 1, 0);
    
    // Create a map for all days in current month
    final dailyRuns = <DateTime, int>{};
    final daysInMonth = lastDayOfMonth.day;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentYear, currentMonth, day);
      dailyRuns[date] = 0;
    }
    
    print('=== BUILD TRENDS CHART DEBUG ===');
    print('Current date: ${now.toIso8601String()}');
    print('Current month: $currentMonth, Year: $currentYear');
    print('First day of month: ${firstDayOfMonth.toIso8601String()}');
    print('Last day of month: ${lastDayOfMonth.toIso8601String()}');
    print('Days in month: $daysInMonth');
    print('Total workflow runs: ${_workflowRuns.length}');
    
    // Print all available dates in the chart range
    print('Chart shows all days in current month:');
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentYear, currentMonth, day);
      print('  Day $day: ${date.toIso8601String()} (${date.day}/${date.month})');
    }

    // Process each workflow run and count builds per day
    for (final run in _workflowRuns) {
      final runDate = DateTime(run.createdAt.year, run.createdAt.month, run.createdAt.day);
      print('Run ${run.id}: ${run.createdAt.toIso8601String()} -> ${runDate.toIso8601String()}');
      
      // Check if this date is in current month
      bool dateInRange = false;
      DateTime? matchedDate;
      for (final chartDate in dailyRuns.keys) {
        if (chartDate.year == runDate.year && 
            chartDate.month == runDate.month && 
            chartDate.day == runDate.day) {
          dateInRange = true;
          matchedDate = chartDate;
          break;
        }
      }
      
      if (dateInRange) {
        dailyRuns[matchedDate!] = (dailyRuns[matchedDate] ?? 0) + 1;
        print('  ✅ Added to date ${matchedDate.toIso8601String()}, count: ${dailyRuns[matchedDate]}');
      } else {
        print('  ❌ Date ${runDate.toIso8601String()} not in current month (${currentMonth}/${currentYear})');
      }
    }
    
    print('Final daily runs: $dailyRuns');
    
    // Show a summary of what will be displayed
    print('=== CHART SUMMARY ===');
    final summaryDates = dailyRuns.keys.toList()..sort();
    for (final date in summaryDates) {
      final count = dailyRuns[date] ?? 0;
      print('${date.day}/${date.month}: ${count} builds');
    }
    print('=== END BUILD TRENDS CHART DEBUG ===');

    final sortedDates = dailyRuns.keys.toList()..sort();
    print('Sorted dates: ${sortedDates.map((d) => '${d.month}/${d.day}').toList()}');
    
    final spots = sortedDates.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), dailyRuns[entry.value]!.toDouble());
    }).toList();
    
    print('Spots data: ${spots.map((s) => '(${s.x}, ${s.y})').toList()}');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build Trends (${_getMonthName(currentMonth)} ${currentYear})',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 5,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF334155),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF334155),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 5,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() >= sortedDates.length) return const Text('');
                        final date = sortedDates[value.toInt()];
                        
                        // Show date labels every 3 days to avoid crowding
                        if (value.toInt() % 3 == 0 || value.toInt() == sortedDates.length - 1) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '${date.day}/${date.month}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                      reservedSize: 42,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                minX: 0,
                maxX: (sortedDates.length - 1).toDouble(),
                minY: 0,
                maxY: dailyRuns.values.isEmpty ? 10 : dailyRuns.values.reduce((a, b) => a > b ? a : b).toDouble() + 2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF3B82F6),
                        const Color(0xFF3B82F6).withOpacity(0.1),
                      ],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF3B82F6),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.3),
                          const Color(0xFF3B82F6).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessRateChart() {
    final totalBuilds = _workflowRuns.length;
    final successfulBuilds = _workflowRuns.where((run) => run.conclusion == 'success').length;
    final failedBuilds = _workflowRuns.where((run) => run.conclusion == 'failure').length;
    final successRate = totalBuilds > 0 ? (successfulBuilds / totalBuilds) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Success Rate',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: CircularPercentIndicator(
              radius: 80.0,
              lineWidth: 12.0,
              percent: successRate,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(successRate * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Success',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              progressColor: const Color(0xFF10B981),
              backgroundColor: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 24),
          _buildLegendItem('Successful', '$successfulBuilds builds', const Color(0xFF10B981)),
          const SizedBox(height: 8),
          _buildLegendItem('Failed', '$failedBuilds builds', const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBuilds() {
    final recentRuns = _workflowRuns.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Builds',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-refresh',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // Navigate to build history
                },
                icon: const Icon(Icons.history, color: Color(0xFF3B82F6)),
                label: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentRuns.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No recent builds found',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...recentRuns.map((run) => _buildBuildItem(run)),
        ],
      ),
    );
  }

  Widget _buildBuildItem(WorkflowRun run) {
    Color statusColor;
    String statusText;
    
    switch (run.conclusion) {
      case 'success':
        statusColor = Colors.green;
        statusText = 'Success';
        break;
      case 'failure':
        statusColor = Colors.red;
        statusText = 'Failed';
        break;
      case 'cancelled':
        statusColor = Colors.orange;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = const Color(0xFF94A3B8);
        statusText = 'Running';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.headCommit,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  run.headBranch,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusText,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${run.durationString} (${run.runStartedAt != null && run.completedAt != null ? '${run.completedAt!.difference(run.runStartedAt!).inSeconds}s' : 'N/A'})',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Text(
            run.timeAgo,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Analytics View - Coming Soon',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
    );
  }
}

class BuildHistoryView extends StatelessWidget {
  const BuildHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Build History View - Coming Soon',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
    );
  }
}
