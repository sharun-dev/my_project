import 'package:flutter/material.dart';

class AuditionManagementScreen extends StatefulWidget {
  final List<Map<String, dynamic>> auditions;
  final String initialFilter;

  const AuditionManagementScreen({
    super.key,
    required this.auditions,
    this.initialFilter = 'All',
  });

  @override
  State<AuditionManagementScreen> createState() => _AuditionManagementScreenState();
}

class _AuditionManagementScreenState extends State<AuditionManagementScreen> {
  late String _selectedFilter;
  final List<String> _filters = ['All', 'Applications', 'Accepted', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  List<Map<String, dynamic>> _getFilteredApplications() {
    final List<Map<String, dynamic>> allApplications = [];
    
    // Flatten all applications from all auditions
    for (var audition in widget.auditions) {
      for (var application in audition['applications']) {
        final appWithAudition = Map<String, dynamic>.from(application);
        appWithAudition['auditionTitle'] = audition['title'];
        appWithAudition['auditionId'] = audition['id'];
        allApplications.add(appWithAudition);
      }
    }

    // Filter based on selected filter
    if (_selectedFilter == 'All') {
      return allApplications;
    } else if (_selectedFilter == 'Applications') {
      return allApplications.where((app) => app['status'] == 'Applied').toList();
    } else if (_selectedFilter == 'Accepted') {
      return allApplications.where((app) => app['status'] == 'Accepted').toList();
    } else if (_selectedFilter == 'Rejected') {
      return allApplications.where((app) => app['status'] == 'Rejected').toList();
    }
    
    return allApplications;
  }

  int _getApplicationCount(String filter) {
    int count = 0;
    for (var audition in widget.auditions) {
      final applications = audition['applications'] as List;
      if (filter == 'All') {
        count += applications.length;
      } else if (filter == 'Applications') {
        count += applications.where((app) => app['status'] == 'Applied').length;
      } else if (filter == 'Accepted') {
        count += applications.where((app) => app['status'] == 'Accepted').length;
      } else if (filter == 'Rejected') {
        count += applications.where((app) => app['status'] == 'Rejected').length;
      }
    }
    return count;
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Applications':
        return const Color(0xFF9D4EDD);
      case 'Accepted':
        return const Color(0xFF66BB6A);
      case 'Rejected':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF7B2CBF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredApplications = _getFilteredApplications();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Audition Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(),
          const SizedBox(height: 16),
          
          // Application Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${filteredApplications.length} ${filteredApplications.length == 1 ? 'Application' : 'Applications'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_selectedFilter != 'All')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getFilterColor(_selectedFilter).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getFilterColor(_selectedFilter).withOpacity(0.3)),
                    ),
                    child: Text(
                      _selectedFilter,
                      style: TextStyle(
                        color: _getFilterColor(_selectedFilter),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Applications List
          Expanded(
            child: filteredApplications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredApplications.length,
                    itemBuilder: (context, index) {
                      final application = filteredApplications[index];
                      return _buildApplicationCard(application);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          final count = _getApplicationCount(filter);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _getFilterColor(filter) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _getFilterColor(filter) : Colors.white.withOpacity(0.2),
                  width: isSelected ? 0 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : _getFilterColor(filter).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: isSelected ? _getFilterColor(filter) : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    Color statusColor;
    IconData statusIcon;
    
    switch (application['status']) {
      case 'Accepted':
        statusColor = const Color(0xFF66BB6A);
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = const Color(0xFFEF5350);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFF9D4EDD);
        statusIcon = Icons.access_time;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(application['profileImage']),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Application Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application['applicantName'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        application['applicantRole'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'For: ${application['auditionTitle']}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Applied: ${application['appliedDate']}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.work, color: Colors.white.withOpacity(0.6), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Experience: ${application['experience']}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        application['status'],
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF151522),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewProfile(application),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE0AAFF),
                      side: const BorderSide(color: Color(0xFF7B2CBF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text('View Profile'),
                  ),
                ),
                const SizedBox(width: 8),
                if (application['status'] == 'Applied')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _acceptApplication(application),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF66BB6A),
                        side: const BorderSide(color: Color(0xFF66BB6A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept'),
                    ),
                  ),
                if (application['status'] == 'Applied')
                  const SizedBox(width: 8),
                if (application['status'] == 'Applied')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectApplication(application),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF5350),
                        side: const BorderSide(color: Color(0xFFEF5350)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                    ),
                  ),
                if (application['status'] != 'Applied')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _messageApplicant(application),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9D4EDD),
                        side: const BorderSide(color: Color(0xFF9D4EDD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('Message'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedFilter == 'Applications' ? Icons.assignment_outlined :
            _selectedFilter == 'Accepted' ? Icons.check_circle_outline :
            _selectedFilter == 'Rejected' ? Icons.cancel_outlined : Icons.people_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedFilter == 'Applications' ? 'No Pending Applications' :
            _selectedFilter == 'Accepted' ? 'No Accepted Applications' :
            _selectedFilter == 'Rejected' ? 'No Rejected Applications' : 'No Applications',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            _selectedFilter == 'Applications' ? 'Applications will appear here when artists apply to your auditions' :
            _selectedFilter == 'Accepted' ? 'Accepted applications will appear here' :
            _selectedFilter == 'Rejected' ? 'Rejected applications will appear here' : 'Applications will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_selectedFilter != 'All')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedFilter = 'All';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D4EDD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View All Applications'),
            ),
        ],
      ),
    );
  }

  void _viewProfile(Map<String, dynamic> application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          application['applicantName'],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(application['profileImage']),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: const Color(0xFF9D4EDD), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileDetail('Role', application['applicantRole'], Icons.work),
            const SizedBox(height: 8),
            _buildProfileDetail('Experience', application['experience'], Icons.timeline),
            const SizedBox(height: 8),
            _buildProfileDetail('Contact', application['contact'], Icons.phone),
            const SizedBox(height: 8),
            _buildProfileDetail('Email', application['email'], Icons.email),
            const SizedBox(height: 8),
            _buildProfileDetail('Audition', application['auditionTitle'], Icons.audiotrack),
            const SizedBox(height: 8),
            _buildProfileDetail('Applied On', application['appliedDate'], Icons.calendar_today),
            const SizedBox(height: 8),
            _buildProfileDetail('Status', application['status'], Icons.info),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetail(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE0AAFF), size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _acceptApplication(Map<String, dynamic> application) {
    setState(() {
      // Update application status to Accepted
      for (var audition in widget.auditions) {
        final applications = audition['applications'] as List;
        final appIndex = applications.indexWhere((app) => app['id'] == application['id']);
        if (appIndex != -1) {
          applications[appIndex]['status'] = 'Accepted';
          // Update counts
          audition['acceptedCount'] = (audition['acceptedCount'] ?? 0) + 1;
          audition['appliedCount'] = (audition['appliedCount'] ?? 0) - 1;
          break;
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${application['applicantName']} has been accepted'),
        backgroundColor: const Color(0xFF66BB6A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _rejectApplication(Map<String, dynamic> application) {
    setState(() {
      // Update application status to Rejected
      for (var audition in widget.auditions) {
        final applications = audition['applications'] as List;
        final appIndex = applications.indexWhere((app) => app['id'] == application['id']);
        if (appIndex != -1) {
          applications[appIndex]['status'] = 'Rejected';
          // Update counts
          audition['rejectedCount'] = (audition['rejectedCount'] ?? 0) + 1;
          audition['appliedCount'] = (audition['appliedCount'] ?? 0) - 1;
          break;
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${application['applicantName']} has been rejected'),
        backgroundColor: const Color(0xFFEF5350),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _messageApplicant(Map<String, dynamic> application) {
    // Navigate to chat screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Message Applicant', style: TextStyle(color: Colors.white)),
        content: const Text('Chat functionality will be implemented here', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

