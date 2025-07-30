import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/github_api_service.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'models/project.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/add_project_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }
  
  await AuthService.initializeAuth();
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
      home: const AuthWrapper(),
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
        '/login': (context) => const LoginScreen(),
        '/add-project': (context) => const AddProjectScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  User? _user;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = AuthService.authStateChanges.listen((user) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    });
  }

  Future<void> _checkAuthState() async {
    try {
      // Check if user is already logged in
      final user = AuthService.currentUser;
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking auth state: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF3B82F6),
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_user != null) {
      return const DashboardScreen();
    } else {
      return const LoginScreen();
    }
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<Project> _projects = [];
  String? _selectedProjectId;
  bool _isLoadingProjects = true;
  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _checkScreenSize();
  }

  void _checkScreenSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenWidth = MediaQuery.of(context).size.width;
      setState(() {
        _isMobile = screenWidth < 768;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    if (_isMobile != (screenWidth < 768)) {
      setState(() {
        _isMobile = screenWidth < 768;
      });
    }
  }

  Future<void> _loadProjects() async {
    try {
      final userId = AuthService.userId;
      print('=== PROJECT LOADING DEBUG ===');
      print('AuthService.userId: $userId');
      print('AuthService.userEmail: ${AuthService.userEmail}');
      print('AuthService.isLoggedIn: ${AuthService.isLoggedIn}');
      
      if (userId != null) {
        print('🔄 Loading all projects from projects collection');
        print('📁 Firestore path: projects (no user filtering)');
        print('🔍 Query: collection("projects") - fetching ALL documents');
        
        FirestoreService.getProjects(userId).listen((projects) {
          print('✅ Received ${projects.length} projects from Firestore');
          if (projects.isEmpty) {
            print('⚠️  No projects found in the projects collection');
            print('💡 Make sure you have projects in Firestore at: projects/{documentId}');
          } else {
            for (var project in projects) {
              print('  📁 Project: ${project.name} (${project.fullRepositoryName}) - ID: ${project.id}');
              print('    - Owner: ${project.owner}');
              print('    - Repository: ${project.repository}');
              print('    - Created: ${project.createdAt}');
              print('    - Active: ${project.isActive}');
            }
          }
          
          setState(() {
            _projects = projects;
            _isLoadingProjects = false;
            print('🔄 Updated state with ${projects.length} projects');
            
            // Set selected project if not already set
            if (_selectedProjectId == null && projects.isNotEmpty) {
              _selectedProjectId = projects.first.id;
              print('🎯 Auto-selected project: ${projects.first.name} (ID: ${projects.first.id})');
              // Force a rebuild to load the selected project's data
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {});
                print('🔄 Triggered rebuild after auto-selecting project');
              });
            } else if (projects.isEmpty) {
              print('⚠️  No projects available to select');
            }
          });
        }, onError: (error) {
          print('❌ Error loading projects: $error');
          print('🔍 Check Firestore rules and collection structure');
          setState(() {
            _isLoadingProjects = false;
          });
        });
      } else {
        print('❌ No user ID found - user not logged in');
        setState(() {
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      print('❌ Exception loading projects: $e');
      setState(() {
        _isLoadingProjects = false;
      });
    }
    print('=== END PROJECT LOADING DEBUG ===');
  }

  void _onProjectChanged(String? projectId) {
    setState(() {
      _selectedProjectId = projectId;
    });
    // Reload dashboard data when project changes
    if (projectId != null) {
      // Trigger a rebuild of the dashboard with the new project
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile Header with Project Selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(
              bottom: BorderSide(color: Color(0xFF334155), width: 1),
            ),
          ),
          child: Column(
            children: [
              // Logo and Title
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ActDash',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Project Selection Dropdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: _isLoadingProjects
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                            ),
                          ),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedProjectId,
                          hint: Text(
                            _projects.isEmpty 
                              ? 'No Projects Found' 
                              : 'Select Project (${_projects.length})',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          dropdownColor: const Color(0xFF1E293B),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          underline: Container(),
                          isExpanded: true,
                          menuMaxHeight: 200,
                          items: [
                            ..._projects.map((Project project) {
                              return DropdownMenuItem<String>(
                                value: project.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        project.name,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            if (_projects.isNotEmpty)
                              const DropdownMenuItem<String>(enabled: false, child: Divider(color: Color(0xFF334155))),
                            DropdownMenuItem<String>(
                              value: null,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.add,
                                    color: Color(0xFF3B82F6),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add Project',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF3B82F6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (String? projectId) {
                            if (projectId == null) {
                              Navigator.of(context).pushNamed('/add-project');
                            } else {
                              _onProjectChanged(projectId);
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        // Mobile Navigation Tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(
              bottom: BorderSide(color: Color(0xFF334155), width: 1),
            ),
          ),
          child: Row(
            children: [
              _buildMobileNavItem(Icons.dashboard, 'Dashboard', 0),
              const SizedBox(width: 8),
              _buildMobileNavItem(Icons.analytics, 'Analytics', 1),
              const SizedBox(width: 8),
              _buildMobileNavItem(Icons.history, 'History', 2),
            ],
          ),
        ),
        // Main Content
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildMobileNavItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
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
                child: Column(
                  children: [
                    Row(
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
                          'ActDash',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Project Selection Dropdown
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: _isLoadingProjects
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                                  ),
                                ),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedProjectId,
                                hint: Text(
                                  _projects.isEmpty 
                                    ? 'No Projects Found - Click "Add Project" or check Firestore' 
                                    : 'Select Project (${_projects.length} available)',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                dropdownColor: const Color(0xFF1E293B),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                underline: Container(), // Remove default underline
                                isExpanded: true, // Make dropdown expand to fill container
                                menuMaxHeight: 300, // Limit dropdown height
                                items: [
                                  ..._projects.map((Project project) {
                                    return DropdownMenuItem<String>(
                                      value: project.id,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.folder,
                                            color: Color(0xFF3B82F6),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  project.name,
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  project.fullRepositoryName,
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
                                    );
                                  }).toList(),
                                  if (_projects.isNotEmpty)
                                    const DropdownMenuItem<String>(
                                      enabled: false,
                                      child: Divider(color: Color(0xFF334155)),
                                    ),
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.add,
                                          color: Color(0xFF3B82F6),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _projects.isEmpty ? 'Add Project' : 'Manage Projects',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF3B82F6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (String? projectId) {
                                  if (projectId == null) {
                                    // Navigate to add project screen
                                    Navigator.of(context).pushNamed('/add-project');
                                  } else {
                                    _onProjectChanged(projectId);
                                  }
                                },
                              ),
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
                  ],
                ),
              ),
              // User info
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF3B82F6),
                          child: Text(
                            AuthService.userEmail?.substring(0, 2).toUpperCase() ?? 'U',
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
                                AuthService.userDisplayName ?? 'User',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                AuthService.userEmail ?? 'user@example.com',
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await AuthService.signOut();
                          // The AuthWrapper will automatically navigate to login page
                          // when it receives the auth state change
                        },
                        icon: const Icon(Icons.logout, size: 16),
                        label: Text(
                          'Sign Out',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
        final selectedProject = _selectedProjectId != null && _projects.isNotEmpty
          ? _projects.firstWhere(
              (p) => p.id == _selectedProjectId,
              orElse: () => _projects.first,
            )
          : _projects.isNotEmpty ? _projects.first : null;
        print('🎯 DashboardView - selectedProject: ${selectedProject?.name} (${selectedProject?.id})');
        return DashboardView(project: selectedProject);
      case 1:
        return const AnalyticsView();
      case 2:
        return const BuildHistoryView();
      default:
        final selectedProject = _selectedProjectId != null && _projects.isNotEmpty
          ? _projects.firstWhere(
              (p) => p.id == _selectedProjectId,
              orElse: () => _projects.first,
            )
          : _projects.isNotEmpty ? _projects.first : null;
        return DashboardView(project: selectedProject);
    }
  }
}

class DashboardView extends StatefulWidget {
  final Project? project;
  
  const DashboardView({super.key, this.project});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  List<WorkflowRun> _workflowRuns = [];
  RepositoryStats? _repositoryStats;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  @override
  void didUpdateWidget(DashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when project changes
    if (oldWidget.project?.id != widget.project?.id) {
      print('🔄 Project changed, reloading data');
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if a project is selected
      final project = widget.project;
      if (project == null) {
        setState(() {
          _error = 'No project selected. Please select a project from the dropdown.';
          _isLoading = false;
        });
        return;
      }

      // Configure GitHub API with project settings
      await GitHubApiService.setToken(project.githubToken);
      await GitHubApiService.setRepositoryInfo(project.owner, project.repository);

      // Load data in parallel
      final futures = await Future.wait([
        GitHubApiService.getWorkflowRuns(perPage: 50),
        GitHubApiService.getRepositoryStats(),
      ]);

      final workflowRuns = futures[0] as List<WorkflowRun>;
      final repositoryStats = futures[1] as RepositoryStats;
      
      print('=== LOADED WORKFLOW RUNS ===');
      print('🔍 TEST LOG: Found ${workflowRuns.length} workflow runs');
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




  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 16),
            Text(
              widget.project != null 
                ? 'Loading data for ${widget.project!.name}...'
                : 'Loading GitHub Actions data...',
              style: const TextStyle(color: Color(0xFF94A3B8)),
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
            if (widget.project != null) ...[
              const SizedBox(height: 8),
              Text(
                'Project: ${widget.project!.name} (${widget.project!.fullRepositoryName})',
                style: const TextStyle(color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
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
        // Main content
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.project != null 
                                  ? 'Dashboard - ${widget.project!.name}'
                                  : 'Dashboard',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Monitor your ActDash performance and analytics',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  // Manual refresh button
                                  IconButton(
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
                                  // Status indicator
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.circle, color: Colors.white, size: 6),
                                          const SizedBox(width: 6),
                                          Text(
                                            'All Systems Operational',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.project != null 
                                        ? 'Dashboard - ${widget.project!.name}'
                                        : 'Dashboard',
                                      style: GoogleFonts.inter(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Monitor your ActDash performance and analytics',
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
                    isMobile
                        ? Column(
                            children: [
                              _buildBuildTrendsChart(),
                              const SizedBox(height: 24),
                              _buildSuccessRateChart(),
                            ],
                          )
                        : Row(
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
              );
            },
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
    final avgSeconds = (avgDuration % 60).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return isMobile
            ? Column(
                children: [
                  _buildStatCard('Total Builds', totalBuilds.toString(), Icons.build, Colors.blue),
                  const SizedBox(height: 16),
                  _buildStatCard('Success Rate', '${successRate.toStringAsFixed(1)}%', Icons.check_circle, Colors.green),
                  const SizedBox(height: 16),
                  _buildStatCard('Avg Duration', '${avgMinutes}m ${avgSeconds}s', Icons.timer, Colors.orange),
                  const SizedBox(height: 16),
                  _buildStatCard('Failed Builds', failedBuilds.toString(), Icons.error, Colors.red),
                ],
              )
            : Row(
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
      },
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
                      color: const Color(0xFF334155).withOpacity(0.3),
                      strokeWidth: 0.5,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF334155).withOpacity(0.2),
                      strokeWidth: 0.5,
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
                  border: Border.all(
                    color: const Color(0xFF334155).withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                minX: 0,
                maxX: (sortedDates.length - 1).toDouble(),
                minY: 0,
                maxY: dailyRuns.values.isEmpty ? 10 : dailyRuns.values.reduce((a, b) => a > b ? a : b).toDouble() + 2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
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
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
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
                  // Navigate to build history page
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BuildHistoryPage(),
                    ),
                  );
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
                run.durationString,
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
    return const BuildHistoryPage();
  }
}

class BuildHistoryPage extends StatefulWidget {
  const BuildHistoryPage({super.key});

  @override
  State<BuildHistoryPage> createState() => _BuildHistoryPageState();
}

class _BuildHistoryPageState extends State<BuildHistoryPage> {
  List<WorkflowRun> _allWorkflowRuns = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'all';
  String _selectedBranch = 'all';

  @override
  void initState() {
    super.initState();
    _loadAllWorkflowRuns();
  }

  Future<void> _loadAllWorkflowRuns() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all workflow runs (not just recent ones)
      final allRuns = await GitHubApiService.getWorkflowRuns();
      
      setState(() {
        _allWorkflowRuns = allRuns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading build history: $e';
      });
    }
  }

  List<WorkflowRun> get _filteredRuns {
    return _allWorkflowRuns.where((run) {
      bool statusMatch = _selectedStatus == 'all' || 
                        (_selectedStatus == 'success' && run.conclusion == 'success') ||
                        (_selectedStatus == 'failure' && run.conclusion == 'failure') ||
                        (_selectedStatus == 'cancelled' && run.conclusion == 'cancelled') ||
                        (_selectedStatus == 'running' && run.status == 'in_progress');
      
      bool branchMatch = _selectedBranch == 'all' || run.headBranch == _selectedBranch;
      
      return statusMatch && branchMatch;
    }).toList();
  }

  List<String> get _availableBranches {
    final branches = _allWorkflowRuns.map((run) => run.headBranch).toSet().toList();
    branches.sort();
    return ['all', ...branches];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Build History',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllWorkflowRuns,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(
                bottom: BorderSide(color: Color(0xFF334155), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Status Filter
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.inter(color: Colors.white),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text('All Status')),
                          DropdownMenuItem(value: 'success', child: Text('Success')),
                          DropdownMenuItem(value: 'failure', child: Text('Failed')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                          DropdownMenuItem(value: 'running', child: Text('Running')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Branch Filter
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBranch,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.inter(color: Colors.white),
                        items: _availableBranches.map((branch) {
                          return DropdownMenuItem(
                            value: branch,
                            child: Text(branch == 'all' ? 'All Branches' : branch),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBranch = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Build List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                  )
                : _error != null
                    ? Center(
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
                              onPressed: _loadAllWorkflowRuns,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredRuns.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  color: Color(0xFF94A3B8),
                                  size: 64,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No builds found',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 18),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Try adjusting your filters or check your repository',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredRuns.length,
                            itemBuilder: (context, index) {
                              final run = _filteredRuns[index];
                              return _buildDetailedBuildItem(run);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedBuildItem(WorkflowRun run) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (run.conclusion) {
      case 'success':
        statusColor = Colors.green;
        statusText = 'Success';
        statusIcon = Icons.check_circle;
        break;
      case 'failure':
        statusColor = Colors.red;
        statusText = 'Failed';
        statusIcon = Icons.error;
        break;
      case 'cancelled':
        statusColor = Colors.orange;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFF94A3B8);
        statusText = 'Running';
        statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status and time
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                run.name,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Commit and branch info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                ),
                child: Text(
                  run.headBranch,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  run.headCommit,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Duration and time ago
          Row(
            children: [
              Icon(Icons.timer, color: const Color(0xFF94A3B8), size: 16),
              const SizedBox(width: 4),
              Text(
                run.durationString,
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                run.timeAgo,
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (run.runStartedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, color: const Color(0xFF94A3B8), size: 16),
                const SizedBox(width: 4),
                Text(
                  'Started: ${DateFormat('MMM dd, yyyy HH:mm').format(run.runStartedAt!)}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
