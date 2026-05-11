import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  final supabase = Supabase.instance.client;

  // =========================
  // AUTH / PROFILE
  // =========================

  User? getCurrentUser() {
    return supabase.auth.currentUser;
  }

  String? getCurrentUserId() {
    return supabase.auth.currentUser?.id;
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = getCurrentUser();

    if (user == null) return null;

    final response =
        await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

    return response;
  }

  Future<void> addProfile({
    required String id,
    required String fullName,
    required String email,
    required String phone,
    required String role,
  }) async {
    await supabase.from('profiles').upsert({
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getProfileById(String profileId) async {
    final response =
        await supabase
            .from('profiles')
            .select()
            .eq('id', profileId)
            .maybeSingle();

    return response;
  }

  Future<void> updateProfile({
    required String profileId,
    required Map<String, dynamic> data,
  }) async {
    await supabase.from('profiles').update(data).eq('id', profileId);
  }

  Future<List<Map<String, dynamic>>> getManagers() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name, email, phone, profile_image_url, role')
          .or('role.ilike.manager,role.ilike.project manager')
          .order('full_name', ascending: true);

      debugPrint("Managers response: $response");

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("GET MANAGERS ERROR: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSiteEngineers() async {
    final response = await supabase
        .from('profiles')
        .select()
        .or('role.eq.site engineer,role.eq.site_engineer');

    return List<Map<String, dynamic>>.from(response);
  }

  // =========================
  // PROJECTS
  // =========================

  Future<void> createProject({required Map<String, dynamic> data}) async {
    await supabase.from('projects').insert(data);
  }

  Future<List<Map<String, dynamic>>> getAllProjects() async {
    final response = await supabase
        .from('projects')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getOwnerProjects(String ownerId) async {
    final response = await supabase
        .from('projects')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // MANAGER PROJECTS
  Future<List<Map<String, dynamic>>> getManagerProjects(
    String managerId,
  ) async {
    final response = await supabase
        .from('projects')
        .select()
        .eq('assigned_manager_id', managerId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // SITE ENGINEER PROJECTS
  Future<List<Map<String, dynamic>>> getEngineerProjects(
    String engineerId,
  ) async {
    final response = await supabase
        .from('projects')
        .select()
        .eq('assigned_site_engineer_id', engineerId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getProjectById(String projectId) async {
    final response =
        await supabase
            .from('projects')
            .select()
            .eq('id', projectId)
            .maybeSingle();

    return response;
  }

  Future<void> updateProject({
    required String projectId,
    required Map<String, dynamic> data,
  }) async {
    await supabase.from('projects').update(data).eq('id', projectId);
  }

  // OWNER ASSIGNS MANAGER
  Future<void> assignManagerToProject({
    required String projectId,
    required String managerId,
  }) async {
    await supabase
        .from('projects')
        .update({'assigned_manager_id': managerId})
        .eq('id', projectId);
  }

  // MANAGER ASSIGNS SITE ENGINEER
  Future<void> assignEngineerToProject({
    required String projectId,
    required String engineerId,
  }) async {
    await supabase
        .from('projects')
        .update({'assigned_site_engineer_id': engineerId})
        .eq('id', projectId);
  }

  Future<void> deleteProject(String projectId) async {
    await supabase
        .from('project_materials')
        .delete()
        .eq('project_id', projectId);

    await supabase
        .from('project_equipment')
        .delete()
        .eq('project_id', projectId);

    await supabase.from('attendance').delete().eq('project_id', projectId);

    await supabase.from('projects').delete().eq('id', projectId);
  }

  // =========================
  // SUPPORT TICKETS
  // =========================

  Future<void> createSupportTicket({
    required String userId,
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    await supabase.from('support_tickets').insert({
      'user_id': userId,
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
      'status': 'open',
    });
  }

  // =========================
  // MATERIALS
  // =========================

  Future<List<Map<String, dynamic>>> getMaterialCatalog() async {
    final response = await supabase
        .from('material_catalog')
        .select()
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getProjectMaterials(
    String projectId,
  ) async {
    final response = await supabase
        .from('project_materials')
        .select('*, material_catalog(name, unit)')
        .eq('project_id', projectId)
        .order('last_update', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addProjectMaterial({
    required String projectId,
    required String materialId,
    required int requiredQuantity,
    required int availableQuantity,
    required int usedQuantity,
    required String deliveryStatus,
  }) async {
    await supabase.from('project_materials').insert({
      'project_id': projectId,
      'material_id': materialId,
      'required_quantity': requiredQuantity,
      'available_quantity': availableQuantity,
      'used_quantity': usedQuantity,
      'delivery_status': deliveryStatus,
    });
  }

  Future<void> updateProjectMaterial({
    required String id,
    required int requiredQuantity,
    required int availableQuantity,
    required int usedQuantity,
    required String deliveryStatus,
  }) async {
    await supabase
        .from('project_materials')
        .update({
          'required_quantity': requiredQuantity,
          'available_quantity': availableQuantity,
          'used_quantity': usedQuantity,
          'delivery_status': deliveryStatus,
          'last_update': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteProjectMaterial(String id) async {
    await supabase.from('project_materials').delete().eq('id', id);
  }

  // =========================
  // EQUIPMENT
  // =========================

  Future<List<Map<String, dynamic>>> getEquipmentCatalog() async {
    final response = await supabase
        .from('equipment_catalog')
        .select()
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getProjectEquipment(
    String projectId,
  ) async {
    final response = await supabase
        .from('project_equipment')
        .select('*, equipment_catalog(name, type)')
        .eq('project_id', projectId)
        .order('last_update', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addProjectEquipment({
    required String projectId,
    required String equipmentId,
    required int requiredQuantity,
    required int availableQuantity,
    required String conditionStatus,
    required String challanNo,
  }) async {
    await supabase.from('project_equipment').insert({
      'project_id': projectId,
      'equipment_id': equipmentId,
      'required_quantity': requiredQuantity,
      'available_quantity': availableQuantity,
      'condition_status': conditionStatus,
      'challan_no': challanNo,
    });
  }

  Future<void> updateProjectEquipment({
    required String id,
    required int requiredQuantity,
    required int availableQuantity,
    required String conditionStatus,
    required String challanNo,
  }) async {
    await supabase
        .from('project_equipment')
        .update({
          'required_quantity': requiredQuantity,
          'available_quantity': availableQuantity,
          'condition_status': conditionStatus,
          'challan_no': challanNo,
          'last_update': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteProjectEquipment(String id) async {
    await supabase.from('project_equipment').delete().eq('id', id);
  }

  // =========================
  // CHAT
  // =========================

  Future<List<Map<String, dynamic>>> getProjectChatMessages(
    String projectId,
  ) async {
    final response = await supabase
        .from('chat_messages')
        .select(
          '*, sender:profiles!project_chat_messages_sender_id_fkey(full_name, email)',
        )
        .eq('project_id', projectId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> sendProjectChatMessage({
    required String projectId,
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    await supabase.from('chat_messages').insert({
      'project_id': projectId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
    });
  }

  // =========================
  // DIGITAL TWIN
  // =========================

  Future<Map<String, dynamic>?> getLatestDigitalTwinSnapshot(
    String projectId,
  ) async {
    final response =
        await supabase
            .from('digital_twin_snapshots')
            .select()
            .eq('project_id', projectId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

    return response;
  }
}
