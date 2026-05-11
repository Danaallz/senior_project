import 'package:flutter/material.dart';

import 'package:senior_project/services/supabase_service.dart';

class AddProjectMaterialPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final Map<String, dynamic>? existingMaterial;

  const AddProjectMaterialPage({
    super.key,
    required this.projectId,
    this.projectName = ' ',
    this.existingMaterial,
  });

  @override
  State<AddProjectMaterialPage> createState() => _AddProjectMaterialPageState();
}

class _AddProjectMaterialPageState extends State<AddProjectMaterialPage> {
  final _formKey = GlobalKey<FormState>();

  final SupabaseService supabaseService = SupabaseService();

  static const Color primaryColor = Color(0xff0d1b46);

  static const Color orangeColor = Color(0xffffb627);

  List<Map<String, dynamic>> catalog = [];

  Map<String, dynamic>? selectedMaterial;

  final requiredController = TextEditingController();

  final availableController = TextEditingController();

  final usedController = TextEditingController();

  String deliveryStatus = 'Delivered';

  bool isLoading = true;
  bool isSaving = false;

  bool get isEditMode => widget.existingMaterial != null;

  final List<String> deliveryStatuses = [
    'Delivered',
    'Pending',
    'Requested',
    'Delayed',
    'Missing',
  ];

  final List<int> requiredQuantityOptions = [
    1,
    5,
    10,
    20,
    25,
    50,
    75,
    100,
    150,
    200,
    250,
    300,
    500,
    750,
    1000,
    1500,
    2000,
    3000,
    5000,
    7500,
    10000,
  ];

  @override
  void initState() {
    super.initState();
    loadCatalog();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  int? controllerNumber(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  List<int> optionsWithValue(List<int> options, int? value) {
    final set =
        <int>{...options, if (value != null && value >= 0) value}.toList();

    set.sort();

    return set;
  }

  List<int> limitedQuantityOptions({
    required int? max,
    bool includeZero = true,
  }) {
    final base = [if (includeZero) 0, ...requiredQuantityOptions];

    if (max == null) {
      return base;
    }

    final values = base.where((number) => number <= max).toList();

    if (!values.contains(max)) {
      values.add(max);
    }

    values.sort();

    return values;
  }

  Future<void> loadCatalog() async {
    try {
      final result = await supabaseService.getMaterialCatalog();

      if (!mounted) return;

      setState(() {
        catalog = result;

        if (isEditMode) {
          final existing = widget.existingMaterial!;

          final materialId = cleanText(existing['material_id']);

          final matchingMaterials =
              catalog
                  .where((material) => cleanText(material['id']) == materialId)
                  .toList();

          selectedMaterial =
              matchingMaterials.isEmpty ? null : matchingMaterials.first;

          requiredController.text = cleanText(existing['required_quantity']);

          availableController.text = cleanText(existing['available_quantity']);

          usedController.text = cleanText(existing['used_quantity']);

          final status = cleanText(existing['delivery_status']);

          if (deliveryStatuses.contains(status)) {
            deliveryStatus = status;
          }
        }

        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load materials: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? validateSelectedQuantity(int? value, {bool allowZero = true}) {
    if (value == null) {
      return 'Please select a quantity';
    }

    if (!allowZero && value <= 0) {
      return 'Quantity must be at least 1';
    }

    if (value < 0) {
      return 'Quantity cannot be negative';
    }

    return null;
  }

  Future<void> saveMaterial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select material.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final required = controllerNumber(requiredController);

    final available = controllerNumber(availableController);

    final used = controllerNumber(usedController);

    if (required == null || available == null || used == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all quantities.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    if (used > required || available > required) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Used and available quantities cannot be greater than required.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      if (isEditMode) {
        await supabaseService.updateProjectMaterial(
          id: widget.existingMaterial!['id'].toString(),
          requiredQuantity: required,
          availableQuantity: available,
          usedQuantity: used,
          deliveryStatus: deliveryStatus,
        );
      } else {
        await supabaseService.addProjectMaterial(
          projectId: widget.projectId,
          materialId: selectedMaterial!['id'].toString(),
          requiredQuantity: required,
          availableQuantity: available,
          usedQuantity: used,
          deliveryStatus: deliveryStatus,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  InputDecoration dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor),
      ),
    );
  }

  Widget quantityDropdown({
    required String label,
    required TextEditingController controller,
    required List<int> options,
    required bool allowZero,
    required IconData icon,
  }) {
    final selected = controllerNumber(controller);

    final allOptions = optionsWithValue(options, selected);

    return DropdownButtonFormField<int>(
      value: selected,
      isExpanded: true,
      decoration: dec(
        label,
      ).copyWith(prefixIcon: Icon(icon, color: primaryColor, size: 20)),
      items:
          allOptions.map((number) {
            return DropdownMenuItem<int>(value: number, child: Text('$number'));
          }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          controller.text = value.toString();

          if (controller == requiredController) {
            final available = controllerNumber(availableController);

            final used = controllerNumber(usedController);

            if (available != null && available > value) {
              availableController.text = value.toString();
            }

            if (used != null && used > value) {
              usedController.text = value.toString();
            }
          }
        });
      },
      validator:
          (value) => validateSelectedQuantity(value, allowZero: allowZero),
    );
  }

  Widget sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  void dispose() {
    requiredController.dispose();
    availableController.dispose();
    usedController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requiredQuantity = controllerNumber(requiredController);

    final selectedUnit = cleanText(selectedMaterial?['unit']);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditMode ? 'Edit Material' : 'Add Material',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: orangeColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          isEditMode
                              ? 'Update Material Stock'
                              : 'Add Material Inventory',
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      sectionTitle('Material Details'),

                      const SizedBox(height: 10),

                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedMaterial,
                        isExpanded: true,
                        decoration: dec('Material').copyWith(
                          prefixIcon: const Icon(
                            Icons.inventory,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        items:
                            catalog
                                .map(
                                  (
                                    item,
                                  ) => DropdownMenuItem<Map<String, dynamic>>(
                                    value: item,
                                    child: Text(
                                      '${item['name'] ?? 'Material'} (${item['unit'] ?? 'unit'})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            isEditMode
                                ? null
                                : (value) {
                                  setState(() {
                                    selectedMaterial = value;
                                  });
                                },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select material';
                          }

                          return null;
                        },
                      ),

                      if (selectedUnit.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Unit: $selectedUnit',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      sectionTitle('Quantities'),

                      const SizedBox(height: 10),

                      quantityDropdown(
                        label: 'Required Quantity',
                        controller: requiredController,
                        options: requiredQuantityOptions,
                        allowZero: false,
                        icon: Icons.format_list_numbered,
                      ),

                      const SizedBox(height: 16),

                      quantityDropdown(
                        label: 'Available Quantity',
                        controller: availableController,
                        options: limitedQuantityOptions(max: requiredQuantity),
                        allowZero: true,
                        icon: Icons.inventory_2,
                      ),

                      const SizedBox(height: 16),

                      quantityDropdown(
                        label: 'Used Quantity',
                        controller: usedController,
                        options: limitedQuantityOptions(max: requiredQuantity),
                        allowZero: true,
                        icon: Icons.remove_done,
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: deliveryStatus,
                        decoration: dec('Delivery Status').copyWith(
                          prefixIcon: const Icon(
                            Icons.local_shipping,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        items:
                            deliveryStatuses.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              deliveryStatus = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : saveMaterial,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child:
                              isSaving
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    isEditMode
                                        ? 'Save Changes'
                                        : 'Save Material',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
