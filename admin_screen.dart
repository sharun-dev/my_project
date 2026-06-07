import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/firestore_service.dart';
import 'login_page.dart';
import 'professional_login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {

  Future<void> _updateUserStatus(
    String collection,
    String docId,
    String status, {
    String? rejectionReason,
  }) async {
    try {
      final updateData = <String, dynamic>{'status': status};
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        updateData['rejectionReason'] = rejectionReason;
      }
      await FirebaseFirestore.instance.collection(collection).doc(docId).update(updateData);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$status applied')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Future<void> _deleteDocument(String collection, String docId) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _showRejectionReasonDialog({
    required String collection,
    required String docId,
  }) async {
    final TextEditingController reasonController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171731),
          title: const Text('Reject User', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: Color.fromARGB(255, 7, 6, 6)),
                decoration: const InputDecoration(
                  hintText: 'Enter rejection reason',
                  hintStyle: TextStyle(color: Color.fromARGB(179, 10, 9, 9)),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reason is required for rejection')),
                  );
                  return;
                }
                Navigator.of(context).pop();
                await _updateUserStatus(
                  collection,
                  docId,
                  'rejected',
                  rejectionReason: reason,
                );
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF170A3A), Color(0xFF2A0F5D)],
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('accountType', isEqualTo: 'regular')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No regular users found'));
          }
          var docs = snapshot.data!.docs;
          // Sort by status: pending first, then verified, then others
          docs.sort((a, b) {
            final statusA = (a['status'] as String?) ?? 'pending';
            final statusB = (b['status'] as String?) ?? 'pending';
            final statusOrder = {'pending': 0, 'requesting': 0, 'verified': 1, 'rejected': 2};
            return (statusOrder[statusA] ?? 3).compareTo(statusOrder[statusB] ?? 3);
          });
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final status = (data['status'] as String?) ?? 'pending';
              Color borderColor = Colors.grey.shade300;
              if (status == 'verified') {
                borderColor = Colors.green.shade700;
              } else if (status == 'rejected') {
                borderColor = Colors.red.shade700;
              }
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: borderColor, width: 4),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade100,
                    child: const Icon(Icons.person, color: Colors.deepPurple),
                  ),
                  title: Text(
                    data['username'] ?? data['name'] ?? 'Unnamed User',
                  ),
                  subtitle: Text(
                    'Email: ${data['email'] ?? '-'}\n'
                    'Phone: ${data['phone'] ?? '-'}\n'
                    'Joined: ${data['createdAt'] != null ? (data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate().toLocal().toString().split('.').first : data['createdAt'].toString()) : '-'}\n'
                    'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'verified',
                        child: Text('Verify'),
                      ),
                      const PopupMenuItem(
                        value: 'rejected',
                        child: Text('Reject'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'rejected') {
                        await _showRejectionReasonDialog(
                          collection: 'users',
                          docId: docs[i].id,
                        );
                      } else if (value == 'delete') {
                        await _deleteDocument('users', docs[i].id);
                      } else {
                        await _updateUserStatus('users', docs[i].id, value);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfessionalsTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF170A3A), Color(0xFF2A0F5D)],
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('profession').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No professionals found'));
          }
          var docs = snapshot.data!.docs;
          // Sort by status: pending first, then verified, then others
          docs.sort((a, b) {
            final statusA = (a['status'] as String?) ?? 'pending';
            final statusB = (b['status'] as String?) ?? 'pending';
            final statusOrder = {'pending': 0, 'requesting': 0, 'verified': 1, 'rejected': 2};
            return (statusOrder[statusA] ?? 3).compareTo(statusOrder[statusB] ?? 3);
          });
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final idProofStatus = data['idProofStatus'] ?? 'not_submitted';
              final status = (data['status'] as String?) ?? 'pending';
              Color borderColor = Colors.grey.shade300;
              if (status == 'verified') {
                borderColor = Colors.green.shade700;
              } else if (status == 'rejected') {
                borderColor = Colors.red.shade700;
              }
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: borderColor, width: 4),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.work, color: Colors.blue),
                  ),
                  title: Text(
                    data['name'] ?? data['username'] ?? 'Unnamed Professional',
                  ),
                  subtitle: Text(
                    '${data['role'] ?? '-'} • ${data['location'] ?? '-'}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: ${data['email'] ?? '-'}'),
                          Text('Phone: ${data['phone'] ?? '-'}'),
                          Text('Social: ${data['socialMedia'] ?? '-'}'),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'ID Proof: ${data['idProofFileName'] ?? '-'} ($idProofStatus)',
                                ),
                              ),
                              if ((data['idProofUrl'] as String?)?.isNotEmpty ?? false)
                                TextButton(
                                  onPressed: () => _showIdProofDialog(data['idProofUrl'] as String),
                                  child: const Text('View', style: TextStyle(color: Color(0xFF9D4EDD))),
                                ),
                            ],
                          ),
                          if (data['role'] == 'Production House') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Business Identity: ${data['businessIdentityFileName'] ?? '-'}',
                                  ),
                                ),
                                if ((data['businessIdentityUrl'] as String?)?.isNotEmpty ?? false)
                                  TextButton(
                                    onPressed: () => _showDocumentDialog(data['businessIdentityUrl'] as String),
                                    child: const Text('View', style: TextStyle(color: Color(0xFF9D4EDD))),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'GST Certificate: ${data['gstCertificateFileName'] ?? '-'}',
                                  ),
                                ),
                                if ((data['gstCertificateUrl'] as String?)?.isNotEmpty ?? false)
                                  TextButton(
                                    onPressed: () => _showDocumentDialog(data['gstCertificateUrl'] as String),
                                    child: const Text('View', style: TextStyle(color: Color(0xFF9D4EDD))),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Certificate of Incorporation: ${data['certificateOfIncorporationFileName'] ?? '-'}',
                                  ),
                                ),
                                if ((data['certificateOfIncorporationUrl'] as String?)?.isNotEmpty ?? false)
                                  TextButton(
                                    onPressed: () => _showDocumentDialog(data['certificateOfIncorporationUrl'] as String),
                                    child: const Text('View', style: TextStyle(color: Color(0xFF9D4EDD))),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Business Address: ${data['businessAddressFileName'] ?? '-'}',
                                  ),
                                ),
                                if ((data['businessAddressUrl'] as String?)?.isNotEmpty ?? false)
                                  TextButton(
                                    onPressed: () => _showDocumentDialog(data['businessAddressUrl'] as String),
                                    child: const Text('View', style: TextStyle(color: Color(0xFF9D4EDD))),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Authority Proof: ${data['authorityProofFileName'] ?? '-'}',
                                  ),
                                ),
                                if ((data['authorityProofUrl'] as String?)?.isNotEmpty ?? false)
                                  TextButton(
                                    onPressed: () => _showDocumentDialog(data['authorityProofUrl'] as String),
                                    child: const Text('View', style: TextStyle(color: Color(0xFF9D4EDD))),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Authorized Signatory: ${data['authorizedSignatoryFileName'] ?? '-'}',
                                  ),
                                ),
                                if ((data['authorizedSignatoryUrl'] as String?)?.isNotEmpty ?? false)
                                  TextButton(
                                    onPressed: () => _showDocumentDialog(data['authorizedSignatoryUrl'] as String),
                                    child: const Text('View', style: TextStyle(color: Color(0xFF9D4EDD))),
                                  ),
                              ],
                            ),
                          ],
                          Text(
                            'Account: ${status[0].toUpperCase()}${status.substring(1)}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  await _updateUserStatus(
                                    'profession',
                                    docs[i].id,
                                    'verified',
                                  );
                                  if (data['role'] == 'Production House') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ProfessionalLoginScreen(),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Verify'),
                              ),
                              TextButton(
                                onPressed: () => _updateUserStatus(
                                  'profession',
                                  docs[i].id,
                                  'rejected',
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _deleteDocument('profession', docs[i].id),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReportsTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF170A3A), Color(0xFF2A0F5D)],
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No reports found'));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final reporterId = data['reporterId'] as String?;
              final reportedId = data['reportedId'] as String?;
              final message = data['message'] as String?;
              final timestamp = data['timestamp'] as Timestamp?;
              final reportType = data['reportType'] as String? ?? 'user';

              return FutureBuilder<List<Map<String, dynamic>?>>(
                future: Future.wait([
                  if (reporterId != null) FirestoreService.getUserData(reporterId) else Future.value(null),
                  if (reportedId != null) FirestoreService.getUserData(reportedId) else Future.value(null),
                ]),
                builder: (context, userSnapshot) {
                  final reporterData = userSnapshot.data?.isNotEmpty == true ? userSnapshot.data![0] : null;
                  final reportedData = userSnapshot.data?.length == 2 ? userSnapshot.data![1] : null;

                  final reporterName = reporterData?['name'] ?? 'Unknown Reporter';
                  final reportedName = reportedData?['name'] ?? (reportType == 'app' ? 'App' : 'Unknown Reported');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: const Icon(Icons.report, color: Colors.orange),
                      ),
                      title: Text(
                        'Report by $reporterName',
                      ),
                      subtitle: Text(
                        'Reported: $reportedName • ${timestamp != null ? timestamp.toDate().toLocal().toString().split('.').first : 'Unknown time'}',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (reporterData != null) ...[
                                Text(
                                  'Reporter Details:',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text('Email: ${reporterData['email'] ?? 'N/A'}'),
                                Text('Location: ${reporterData['location'] ?? 'N/A'}'),
                                Text('Phone: ${reporterData['phone'] ?? 'N/A'}'),
                                const SizedBox(height: 16),
                              ],
                              if (reportedData != null) ...[
                                Text(
                                  'Reported Person Details:',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text('Role: ${reportedData['role'] ?? 'N/A'}'),
                                Text('Specialization: ${reportedData['specialization'] ?? 'N/A'}'),
                                Text('Email: ${reportedData['email'] ?? 'N/A'}'),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                'Message:',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(message ?? 'No message'),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => _updateUserStatus(
                                      'reports',
                                      docs[i].id,
                                      'reviewed',
                                    ),
                                    child: const Text(
                                      'Mark as Reviewed',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteDocument('reports', docs[i].id),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showIdProofDialog(String idProofUrl) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        final isImageUrl = idProofUrl.toLowerCase().endsWith('.jpg') ||
            idProofUrl.toLowerCase().endsWith('.jpeg') ||
            idProofUrl.toLowerCase().endsWith('.png') ||
            idProofUrl.toLowerCase().endsWith('.gif') ||
            idProofUrl.toLowerCase().endsWith('.bmp') ||
            idProofUrl.toLowerCase().endsWith('.webp');

        return AlertDialog(
          backgroundColor: const Color(0xFF171731),
          title: const Text('ID Proof', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: isImageUrl
                ? Image.network(
                    idProofUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text('Cannot load image', style: TextStyle(color: Colors.white));
                    },
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('ID Proof is not an image. Open in browser to view.', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final uri = Uri.parse(idProofUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text('Open ID Proof'),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDocumentDialog(String documentUrl) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        final isImageUrl = documentUrl.toLowerCase().endsWith('.jpg') ||
            documentUrl.toLowerCase().endsWith('.jpeg') ||
            documentUrl.toLowerCase().endsWith('.png') ||
            documentUrl.toLowerCase().endsWith('.gif') ||
            documentUrl.toLowerCase().endsWith('.bmp') ||
            documentUrl.toLowerCase().endsWith('.webp');

        return AlertDialog(
          backgroundColor: const Color(0xFF171731),
          title: const Text('Document', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: isImageUrl
                ? Image.network(
                    documentUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text('Cannot load image', style: TextStyle(color: Colors.white));
                    },
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Document is not an image. Open in browser to view.', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final uri = Uri.parse(documentUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text('Open Document'),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1B),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text('Admin Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A227E), Color(0xFF0F0F1B)],
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'LOGOUT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _logout,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF171731),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.95,
                  child: const TabBar(
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                      gradient: LinearGradient(colors: [Color(0xFF9D4EDD), Color(0xFF6C63FF)]),
                    ),
                    labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: TextStyle(fontSize: 13),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(icon: Icon(Icons.people, size: 18), text: 'Users'),
                      Tab(icon: Icon(Icons.work, size: 18), text: 'Professionals'),
                      Tab(icon: Icon(Icons.report, size: 18), text: 'Reports'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0F1B), Color(0xFF151522)],
            ),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [_buildUsersTab(), _buildProfessionalsTab(), _buildReportsTab()],
            ),
          ),
        ),
      ),
    );
  }
}
