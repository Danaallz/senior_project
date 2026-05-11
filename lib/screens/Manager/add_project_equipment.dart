import 'package:flutter/material.dart';

import 'package:senior_project/services/supabase_service.dart';

class AddProjectEquipmentPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final Map<String, dynamic>? existingEquipment;

  const AddProjectEquipmentPage({
    super.key,
    required this.projectId,
    this.projectName = ' ',
    this.existingEquipment,
  });

  @override
  State<AddProjectEquipmentPage> createState() =>
      _AddProjectEquipmentPageState();
}

class _AddProjectEquipmentPageState extends State<AddProjectEquipmentPage> {
  final _formKey = GlobalKey<FormState>();

  final SupabaseService supabaseService = SupabaseService();

  static const Color primaryColor = Color(0xff0d1b46);

  static const Color orangeColor = Color(0xffffb627);

  List<Map<String, dynamic>> catalog = [];

  Map<String, dynamic>? selectedEquipment;

  final requiredController = TextEditingController();

  final availableController = TextEditingController();

  final challanController = TextEditingController();

  String conditionStatus = 'Working';

  bool isLoading = true;
  bool isSaving = false;

  bool get isEditMode => widget.existingEquipment != null;

  final List<String> statuses = ['Working', 'Paused', 'Maintenance', 'Damaged'];

  final List<int> requiredQuantityOptions = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    15,
    20,
    25,
    30,
    40,
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
      final result = await supabaseService.getEquipmentCatalog();

      if (!mounted) return;

      setState(() {
        catalog = result;

        if (isEditMode) {
          final existing = widget.existingEquipment!;

          final equipmentId = cleanText(existing['equipment_id']);

          final matchingEquipment =
              catalog
                  .where(
                    (equipment) => cleanText(equipment['id']) == equipmentId,
                  )
                  .toList();

          selectedEquipment =
              matchingEquipment.isEmpty ? null : matchingEquipment.first;

          requiredController.text = cleanText(existing['required_quantity']);

          availableController.text = cleanText(existing['available_quantity']);

          challanController.text = cleanText(existing['challan_no']);

          final status = cleanText(existing['condition_status']);

          if (statuses.contains(status)) {
            conditionStatus = status;
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
            content: Text('Unable to load equipment: $e'),
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

  String? validateChallan(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Challan number is required';
    }

    if (text.length < 3) {
      return 'Challan number is too short';
    }

    if (text.length > 40) {
      return 'Challan number is too long';
    }

    if (!RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(text)) {
      return 'Only letters, numbers, dash and underscore are allowed';
    }

    return null;
  }

  Future<void> saveEquipment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedEquipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select equipment.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final required = controllerNumber(requiredController);

    final available = controllerNumber(availableController);

    if (required == null || available == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all quantities.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    if (available > required) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Available quantity cannot be greater than required quantity.',
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
        await supabaseService.updateProjectEquipment(
          id: widget.existingEquipment!['id'].toString(),
          requiredQuantity: required,
          availableQuantity: available,
          conditionStatus: conditionStatus,
          challanNo: challanController.text.trim(),
        );
      } else {
        await supabaseService.addProjectEquipment(
          projectId: widget.projectId,
          equipmentId: selectedEquipment!['id'].toString(),
          requiredQuantity: required,
          availableQuantity: available,
          conditionStatus: conditionStatus,
          challanNo: challanController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save equipment: $e'),
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
    VoidCallback? onChangedExtra,
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

            if (available != null && available > value) {
              availableController.text = value.toString();
            }
          }
        });

        onChangedExtra?.call();
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
    challanController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requiredQuantity = controllerNumber(requiredController);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditMode ? 'Edit Equipment' : 'Add Equipment',
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
                              ? 'Update Project Equipment'
                              : 'Add Project Equipment',
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      sectionTitle('Equipment Details'),

                      const SizedBox(height: 10),

                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedEquipment,
                        isExpanded: true,
                        decoration: dec('Equipment').copyWith(
                          prefixIcon: const Icon(
                            Icons.precision_manufacturing,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        items:
                            catalog.map((item) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: item,
                                child: Text(
                                  '${item['name'] ?? 'Equipment'}${item['type'] == null ? '' : ' (${item['type']})'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                        onChanged:
                            isEditMode
                                ? null
                                : (value) {
                                  setState(() {
                                    selectedEquipment = value;
                                  });
                                },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select equipment';
                          }

                          return null;
                        },
                      ),

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

                      TextFormField(
                        controller: challanController,
                        validator: validateChallan,
                        decoration: dec('Challan No').copyWith(
                          prefixIcon: const Icon(
                            Icons.receipt_long,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: conditionStatus,
                        decoration: dec('Condition Status').copyWith(
                          prefixIcon: const Icon(
                            Icons.health_and_safety,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        items:
                            statuses.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              conditionStatus = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : saveEquipment,
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
                                        : 'Save Equipment',
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
