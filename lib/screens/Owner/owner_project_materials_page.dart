import 'package:flutter/material.dart';

import 'package:senior_project/services/supabase_service.dart';

class OwnerProjectMaterialsPage extends StatefulWidget {
  final String projectId;
  final String projectName;

  const OwnerProjectMaterialsPage({
    super.key,
    required this.projectId,
    this.projectName = ' ',
  });

  @override
  State<OwnerProjectMaterialsPage> createState() =>
      _OwnerProjectMaterialsPageState();
}

class _OwnerProjectMaterialsPageState extends State<OwnerProjectMaterialsPage> {
  final SupabaseService supabaseService = SupabaseService();

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color orangeColor = Color(0xffffb627);
  static const Color greenColor = Color(0xff18b26b);
  static const Color purpleColor = Color(0xff6c63ff);
  static const Color borderColor = Color(0xffeeeeee);
  static const Color lightTextColor = Color(0xff8f8f8f);

  bool isLoading = true;
  String search = '';
  int selectedInnerTab = 0;

  List<Map<String, dynamic>> materials = [];

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
      final result = await supabaseService.getProjectMaterials(
        widget.projectId,
      );

      if (!mounted) return;

      setState(() {
        materials = result;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load materials: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool reqStatus(String status) {
    final value = status.toLowerCase();
    return ['pending', 'requested', 'delayed', 'missing'].contains(value);
  }

  List<Map<String, dynamic>> get filtered {
    return materials.where((item) {
      final name = cleanText(item['material_catalog']?['name']).toLowerCase();
      final status = cleanText(item['delivery_status']);

      final matchesSearch = name.contains(search.toLowerCase());
      final matchesTab =
          selectedInnerTab == 0 ? !reqStatus(status) : reqStatus(status);

      return matchesSearch && matchesTab;
    }).toList();
  }

  Color statusColor(String status) {
    final value = status.toLowerCase();

    if (value == 'delivered' || value == 'in stock') {
      return greenColor;
    }

    if (value == 'requested' || value == 'pending') {
      return purpleColor;
    }

    if (value == 'delayed' || value == 'missing') {
      return Colors.red;
    }

    return Colors.grey;
  }

  Widget innerTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [innerTab('Inventory', 0), innerTab('Request', 1)],
        ),
      ),
    );
  }

  Widget innerTab(String title, int index) {
    final selected = selectedInnerTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedInnerTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          decoration: BoxDecoration(
            color: selected ? orangeColor : Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget searchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 43,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          maxLength: 50,
          onChanged: (value) {
            setState(() => search = value);
          },
          decoration: const InputDecoration(
            counterText: '',
            hintText: 'Search',
            hintStyle: TextStyle(fontSize: 12),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, size: 20),
            suffixIcon: Icon(Icons.tune, size: 18, color: primaryColor),
          ),
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

    if (selectedInnerTab == 1) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 58,
              decoration: BoxDecoration(
                color: purpleColor.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date == 'Today' ? '-' : date.split('-').last,
                    style: const TextStyle(
                      color: purpleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Day',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Project request',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$available $unit',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
                Text('$available $unit', style: const TextStyle(fontSize: 11)),
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
              const SizedBox(height: 7),
              const Text(
                'View only',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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
    return Scaffold(
      backgroundColor: Colors.white,
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  const SizedBox(height: 14),
                  innerTabs(),
                  const SizedBox(height: 14),
                  searchBox(),
                  const SizedBox(height: 12),
                  Expanded(
                    child:
                        filtered.isEmpty
                            ? const Center(
                              child: Text(
                                'No materials found.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : RefreshIndicator(
                              onRefresh: loadMaterials,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (_, index) {
                                  return card(filtered[index]);
                                },
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}
