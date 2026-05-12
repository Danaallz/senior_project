import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:senior_project/services/supabase_service.dart';

class EngMaterialsPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const EngMaterialsPage({super.key, required this.project});

  @override
  State<EngMaterialsPage> createState() => _EngMaterialsPageState();
}

class _EngMaterialsPageState extends State<EngMaterialsPage> {
  final SupabaseService supabaseService = SupabaseService();
  final supabase = Supabase.instance.client;

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color purpleColor = Color(0xff6c63ff);
  static const Color greenColor = Color(0xff18b26b);
  static const Color borderColor = Color(0xffeeeeee);
  static const Color lightTextColor = Color(0xff8f8f8f);

  bool isLoading = true;
  String search = '';

  List<Map<String, dynamic>> materials = [];

  String get projectId => widget.project['id'].toString();

  @override
  void initState() {
    super.initState();
    loadMaterials();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  Future<void> loadMaterials() async {
    try {
      final result = await supabaseService.getProjectMaterials(projectId);

      if (!mounted) return;

      setState(() {
        materials = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to load materials: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get filtered {
    return materials.where((item) {
      final name = cleanText(item['material_catalog']?['name']).toLowerCase();
      return name.contains(search.toLowerCase());
    }).toList();
  }

  Color statusColor(String status) {
    final value = status.toLowerCase();

    if (value == 'delivered' || value == 'in stock') return greenColor;
    if (value == 'requested' || value == 'pending') return purpleColor;
    if (value == 'delayed' || value == 'missing') return Colors.red;

    return Colors.grey;
  }

  // ================================
  // MATERIAL REQUEST NOTIFICATION
  // Confirms to the site engineer that a material request was sent.
  // ================================
  Future<void> createMaterialRequestNotification({
    required String itemName,
    required int quantity,
  }) async {
    try {
      final engineerId = supabase.auth.currentUser?.id;
      if (engineerId == null || engineerId.isEmpty) return;

      await supabase.from('notifications').insert({
        'user_id': engineerId,
        'project_id': projectId,
        'type': 'material_request_sent',
        'title': 'Material Request Sent',
        'message': 'Your request for $quantity more $itemName has been submitted.',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Material request notification error: $e');
    }
  }

  Future<void> requestMore(Map<String, dynamic> item) async {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();

    final catalog = item['material_catalog'] ?? {};
    final itemName =
        cleanText(catalog['name']).isEmpty
            ? 'Material'
            : cleanText(catalog['name']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("Request more $itemName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Quantity",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Note",
                  hintText: "Example: Please update the stock",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Send Request"),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final quantity = int.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid quantity"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      final profile =
          user == null
              ? null
              : await supabase
                  .from('profiles')
                  .select('full_name')
                  .eq('id', user.id)
                  .maybeSingle();

      final engineerName =
          cleanText(profile?['full_name']).isEmpty
              ? "Site engineer"
              : cleanText(profile?['full_name']);

      await supabase.from('resource_requests').insert({
        'project_id': projectId,
        'requested_by': user?.id,
        'request_type': 'material',
        'item_name': itemName,
        'quantity': quantity,
        'note':
            noteController.text.trim().isEmpty
                ? 'The site engineer "$engineerName" requested $quantity more $itemName. Please update the stock.'
                : noteController.text.trim(),
        'status': 'pending',
      });

      // ================================
      // CREATE MATERIAL REQUEST NOTIFICATION
      // Confirms request submission for the site engineer.
      // ================================
      await createMaterialRequestNotification(
        itemName: itemName,
        quantity: quantity,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request sent to manager ✅"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to send request: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget searchBox() {
    return Container(
      height: 43,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        maxLength: 50,
        onChanged: (value) => setState(() => search = value),
        decoration: const InputDecoration(
          counterText: '',
          hintText: 'Search materials',
          hintStyle: TextStyle(fontSize: 12),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, size: 20),
        ),
      ),
    );
  }

  Widget card(Map<String, dynamic> item) {
    final catalog = item['material_catalog'] ?? {};

    final name =
        cleanText(catalog['name']).isEmpty
            ? 'Material'
            : cleanText(catalog['name']);

    final unit =
        cleanText(catalog['unit']).isEmpty
            ? 'Numbers'
            : cleanText(catalog['unit']);

    final available = item['available_quantity'] ?? 0;
    final required = item['required_quantity'] ?? 0;
    final used = item['used_quantity'] ?? 0;

    final status =
        cleanText(item['delivery_status']).isEmpty
            ? 'Delivered'
            : cleanText(item['delivery_status']);

    final date =
        cleanText(item['last_update']).isEmpty
            ? 'Today'
            : cleanText(item['last_update']).split('T').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor(status).withOpacity(.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '$available $unit available',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  'Required: $required | Used: $used',
                  style: const TextStyle(fontSize: 10, color: lightTextColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Last update: $date',
                style: const TextStyle(fontSize: 10, color: lightTextColor),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => requestMore(item),
                child: const Text(
                  'Request More',
                  style: TextStyle(
                    color: purpleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: const [
                  Text(
                    "Materials",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: searchBox(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  filtered.isEmpty
                      ? const Center(
                        child: Text(
                          "No materials found.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : RefreshIndicator(
                        onRefresh: loadMaterials,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            return card(filtered[index]);
                          },
                        ),
                      ),
            ),
          ],
        );
  }
}
