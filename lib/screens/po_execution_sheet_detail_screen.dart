@@ .. @@
 import 'package:flutter/material.dart';
 import 'package:http/http.dart' as http;
 import 'dart:convert';
 import 'package:trailblaze_app/models/execution_sheet.dart';
 import 'package:trailblaze_app/models/operation_execution.dart';
 import 'package:trailblaze_app/models/parcel_operation_execution.dart';
-import 'package:trailblaze_app/screens/po_parcel_operation_execution_details_screen.dart';
+import 'package:trailblaze_app/screens/po_parcel_activity_screen.dart';
 import 'package:trailblaze_app/utils/app_constants.dart';
 import 'package:trailblaze_app/models/activity.dart';
+import 'package:trailblaze_app/services/execution_service.dart';

 class PoExecutionSheetDetailsScreen extends StatefulWidget {
@@ .. @@
   void _refreshData() {
     setState(() {
-      _parcelOperationsFuture = _fetchParcelOperations();
+      _parcelOperationsFuture = _fetchExecutionSheetData();
     });
   }

-  Future<List<ParcelOperationExecution>> _fetchParcelOperations() async {
-    final response = await http.get(
-      Uri.parse(
-          'https://trailblaze-460312.appspot.com/rest/fe/${widget.sheet.id}'),
-      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
-    );
-
-    if (response.statusCode == 200) {
-      final Map<String, dynamic> data = jsonDecode(response.body);
-      final List<dynamic> operationsData = data['operations'] ?? [];
-
-      List<ParcelOperationExecution> parcelOperations = [];
-      for (var opData in operationsData) {
-        OperationExecution opExec =
-            OperationExecution.fromJson(opData['operationExecution']);
-        List<dynamic> parcelsData = opData['parcels'] ?? [];
-        for (var parcelData in parcelsData) {
-          ParcelOperationExecution parcelOp =
-              ParcelOperationExecution.fromJson(parcelData['parcelExecution']);
-          parcelOp.operationExecution = opExec;
-          parcelOp.activities = (parcelData['activities'] as List<dynamic>)
-              .map((activityJson) => Activity.fromJson(activityJson))
-              .toList();
-          parcelOperations.add(parcelOp);
-        }
-      }
-      return parcelOperations;
-    } else {
-      throw Exception(
-          'Failed to load data. Status code: ${response.statusCode}');
+  Future<List<ParcelOperationExecution>> _fetchExecutionSheetData() async {
+    try {
+      final data = await ExecutionService.fetchExecutionSheetDetails(
+        sheetId: widget.sheet.id,
+        jwtToken: widget.jwtToken,
+      );
+      
+      final List<dynamic> operationsData = data['operations'] ?? [];
+      List<ParcelOperationExecution> parcelOperations = [];
+      
+      for (var opData in operationsData) {
+        OperationExecution opExec =
+            OperationExecution.fromJson(opData['operationExecution']);
+        List<dynamic> parcelsData = opData['parcels'] ?? [];
+        for (var parcelData in parcelsData) {
+          ParcelOperationExecution parcelOp =
+              ParcelOperationExecution.fromJson(parcelData['parcelExecution']);
+          parcelOp.operationExecution = opExec;
+          parcelOp.activities = (parcelData['activities'] as List<dynamic>)
+              .map((activityJson) => Activity.fromJson(activityJson))
+              .toList();
+          parcelOperations.add(parcelOp);
+        }
+      }
+      return parcelOperations;
+    } catch (e) {
+      throw Exception('Failed to load execution sheet data: $e');
     }
   }

@@ .. @@
               if (assignedParcels.isEmpty) {
-                return const Center(child: Text('You have no assigned operations in this sheet.'));
+                return _buildEmptyState();
               }

-              return ListView.builder(
-                itemCount: assignedParcels.length,
-                itemBuilder: (context, index) {
-                  final parcelOp = assignedParcels[index];
-                  return Card(
-                    margin: const EdgeInsets.all(8.0),
-                    child: ListTile(
-                      title: Text(
-                          'Parcel ID: ${parcelOp.parcelId} - Operation: ${parcelOp.operationExecution?.name ?? 'N/A'}'),
-                      subtitle: Text('Status: ${parcelOp.status}'),
-                      trailing: const Icon(Icons.arrow_forward_ios),
-                      onTap: () {
-                        Navigator.push(
-                          context,
-                          MaterialPageRoute(
-                            builder: (context) =>
-                                PoParcelOperationExecutionDetailsScreen(
-                              parcelOperation: parcelOp,
-                              jwtToken: widget.jwtToken,
-                              username: widget.username,
-                            ),
-                          ),
-                        ).then((_) => _refreshData());
-                      },
-                    ),
-                  );
-                },
+              return _buildParcelOperationsList(assignedParcels);
+            }
+          },
+        ),
+      ),
+    );
+  }
+
+  Widget _buildEmptyState() {
+    return Center(
+      child: Column(
+        mainAxisAlignment: MainAxisAlignment.center,
+        children: [
+          Icon(
+            Icons.assignment_outlined,
+            size: 64,
+            color: Colors.grey.shade400,
+          ),
+          const SizedBox(height: 16),
+          Text(
+            'No assigned operations',
+            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
+              color: Colors.grey.shade600,
+            ),
+          ),
+          const SizedBox(height: 8),
+          Text(
+            'You don\'t have any assigned activities in this execution sheet',
+            textAlign: TextAlign.center,
+            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
+              color: Colors.grey.shade500,
+            ),
+          ),
+        ],
+      ),
+    );
+  }
+
+  Widget _buildParcelOperationsList(List<ParcelOperationExecution> parcels) {
+    return ListView.builder(
+      padding: const EdgeInsets.all(16.0),
+      itemCount: parcels.length,
+      itemBuilder: (context, index) {
+        final parcelOp = parcels[index];
+        return _buildParcelOperationCard(parcelOp);
+      },
+    );
+  }
+
+  Widget _buildParcelOperationCard(ParcelOperationExecution parcelOp) {
+    final myActivities = parcelOp.activities
+        .where((activity) => activity.operatorId == widget.username)
+        .toList();
+    
+    final ongoingActivity = myActivities.firstWhere(
+      (activity) => activity.endTime == null,
+      orElse: () => null as dynamic,
+    );
+    
+    final completedActivities = myActivities
+        .where((activity) => activity.endTime != null)
+        .length;
+
+    return Card(
+      margin: const EdgeInsets.only(bottom: 12.0),
+      elevation: 2,
+      shape: RoundedRectangleBorder(
+        borderRadius: BorderRadius.circular(12),
+      ),
+      child: InkWell(
+        borderRadius: BorderRadius.circular(12),
+        onTap: () {
+          Navigator.push(
+            context,
+            MaterialPageRoute(
+              builder: (context) => PoParcelActivityScreen(
+                parcelOperation: parcelOp,
+                jwtToken: widget.jwtToken,
+                username: widget.username,
+              ),
+            ),
+          ).then((_) => _refreshData());
+        },
+        child: Padding(
+          padding: const EdgeInsets.all(16.0),
+          child: Column(
+            crossAxisAlignment: CrossAxisAlignment.start,
+            children: [
+              Row(
+                children: [
+                  Expanded(
+                    child: Column(
+                      crossAxisAlignment: CrossAxisAlignment.start,
+                      children: [
+                        Text(
+                          'Parcel ${parcelOp.parcelId}',
+                          style: const TextStyle(
+                            fontSize: 18,
+                            fontWeight: FontWeight.bold,
+                            color: AppColors.primaryGreen,
+                          ),
+                        ),
+                        const SizedBox(height: 4),
+                        Text(
+                          parcelOp.operationExecution?.name ?? 'Unknown Operation',
+                          style: TextStyle(
+                            fontSize: 14,
+                            color: Colors.grey.shade600,
+                          ),
+                        ),
+                      ],
+                    ),
+                  ),
+                  _buildStatusChip(parcelOp.status),
+                ],
+              ),
+              const SizedBox(height: 12),
+              
+              // Activity summary
+              Row(
+                children: [
+                  _buildActivitySummaryItem(
+                    icon: Icons.check_circle_outline,
+                    label: 'Completed',
+                    value: completedActivities.toString(),
+                    color: Colors.green,
+                  ),
+                  const SizedBox(width: 16),
+                  if (ongoingActivity != null)
+                    _buildActivitySummaryItem(
+                      icon: Icons.play_circle_outline,
+                      label: 'Ongoing',
+                      value: '1',
+                      color: Colors.blue,
+                    ),
+                ],
+              ),
+              
+              const SizedBox(height: 12),
+              Row(
+                children: [
+                  Icon(
+                    Icons.arrow_forward_ios,
+                    size: 16,
+                    color: Colors.grey.shade400,
+                  ),
+                  const SizedBox(width: 4),
+                  Text(
+                    'Tap to manage activities',
+                    style: TextStyle(
+                      fontSize: 12,
+                      color: Colors.grey.shade500,
+                    ),
+                  ),
+                ],
               );
             }
           },
@@ .. @@
       ),
     );
   }
+
+  Widget _buildStatusChip(String status) {
+    Color backgroundColor;
+    Color textColor;
+    
+    switch (status.toUpperCase()) {
+      case 'ASSIGNED':
+        backgroundColor = Colors.orange.shade100;
+        textColor = Colors.orange.shade800;
+        break;
+      case 'IN_PROGRESS':
+        backgroundColor = Colors.blue.shade100;
+        textColor = Colors.blue.shade800;
+        break;
+      case 'EXECUTED':
+        backgroundColor = Colors.green.shade100;
+        textColor = Colors.green.shade800;
+        break;
+      default:
+        backgroundColor = Colors.grey.shade100;
+        textColor = Colors.grey.shade800;
+    }
+
+    return Container(
+      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
+      decoration: BoxDecoration(
+        color: backgroundColor,
+        borderRadius: BorderRadius.circular(12),
+      ),
+      child: Text(
+        status,
+        style: TextStyle(
+          fontSize: 12,
+          fontWeight: FontWeight.w600,
+          color: textColor,
+        ),
+      ),
+    );
+  }
+
+  Widget _buildActivitySummaryItem({
+    required IconData icon,
+    required String label,
+    required String value,
+    required Color color,
+  }) {
+    return Row(
+      children: [
+        Icon(
+          icon,
+          size: 16,
+          color: color,
+        ),
+        const SizedBox(width: 4),
+        Text(
+          '$value $label',
+          style: TextStyle(
+            fontSize: 12,
+            color: color,
+            fontWeight: FontWeight.w500,
+          ),
+        ),
+      ],
+    );
+  }
 }