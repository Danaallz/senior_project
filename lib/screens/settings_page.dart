import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService supabaseService = SupabaseService();
  final supabase = Supabase.instance.client;

  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();

  Uint8List? selectedProfileImageBytes;

  String? profileId;
  String? profileImageUrl;
  String? selectedCountry;
  String? selectedPhoneCode;

  List<String> countries = [];
  Map<String, String> countryPhoneCodes = {};

  bool isLoading = true;
  bool isSaving = false;
  bool loadingCountries = false;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    await loadCountries();
    await loadProfile();

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  String cleanInput(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[<>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool hasInvalidChars(String value) {
    return RegExp(r'[<>]').hasMatch(value);
  }

  Future<void> loadCountries() async {
    setState(() => loadingCountries = true);

    try {
      final url = Uri.parse(
        'https://countriesnow.space/api/v0.1/countries/codes',
      );

      final response = await http.get(url);

      final body = jsonDecode(response.body);
      final data = body['data'] as List;

      countries = data.map((e) => e['name'].toString()).toList();

      countries.sort();

      countryPhoneCodes = {
        for (var item in data)
          item['name'].toString(): item['dial_code'].toString(),
      };
    } catch (_) {
      countries = [
        'Saudi Arabia',
        'United Arab Emirates',
        'United States',
        'United Kingdom',
      ];

      countryPhoneCodes = {
        'Saudi Arabia': '+966',
        'United Arab Emirates': '+971',
        'United States': '+1',
        'United Kingdom': '+44',
      };
    }

    if (mounted) {
      setState(() => loadingCountries = false);
    }
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final profile =
        await supabaseService.getProfileByFirebaseUid(user.uid);

    if (profile != null) {
      profileId = profile['id'];
      profileImageUrl = profile['profile_image_url'];

      _companyController.text =
          profile['company_name'] ?? '';

      final savedPhone = profile['phone'];

      _phoneController.text =
          savedPhone == null ||
                  savedPhone.toString() == '0'
              ? ''
              : savedPhone.toString();

      _addressController.text =
          profile['address'] ?? '';

      _stateController.text =
          profile['state'] ?? '';

      _cityController.text =
          profile['city'] ?? '';

      _zipController.text =
          profile['zip_code'] ?? '';

      selectedCountry = profile['country'];

      selectedPhoneCode =
          profile['phone_code'] ?? '+966';
    }
  }

  Future<void> pickAndUploadImage() async {
    if (profileId == null) return;

    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    final extension =
        image.name.split('.').last.toLowerCase();

    if (extension != 'jpg' &&
        extension != 'jpeg' &&
        extension != 'png') {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Only JPG and PNG images are allowed.",
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    try {
      selectedProfileImageBytes =
          await image.readAsBytes();

      if (selectedProfileImageBytes!.length >
          5 * 1024 * 1024) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Image size must be less than 5 MB.",
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final fileName =
          'profile_${profileId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('profile-images')
          .uploadBinary(
            fileName,
            selectedProfileImageBytes!,
            fileOptions:
                const FileOptions(upsert: true),
          );

      final imageUrl = supabase.storage
          .from('profile-images')
          .getPublicUrl(fileName);

      await supabaseService.updateProfile(
        profileId: profileId!,
        data: {
          'profile_image_url': imageUrl,
        },
      );

      if (!mounted) return;

      setState(() => profileImageUrl = imageUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile image updated"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to upload image. Please try again.",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    if (profileId == null) return;

    if (selectedCountry == null ||
        selectedCountry!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select country"),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() => isSaving = true);

    try {
      await supabaseService.updateProfile(
        profileId: profileId!,
        data: {
          'company_name':
              cleanInput(_companyController.text),

          'phone_code': selectedPhoneCode,

          'phone':
              cleanInput(_phoneController.text),

          'address':
              cleanInput(_addressController.text),

          'country': selectedCountry,

          'state':
              cleanInput(_stateController.text),

          'city':
              cleanInput(_cityController.text),

          'zip_code':
              cleanInput(_zipController.text),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Settings saved successfully ✅"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to save settings. Please try again.",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> showCountrySearchDialog() async {
    final searchController =
        TextEditingController();

    List<String> filteredCountries =
        List.from(countries);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Select Country"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      maxLength: 50,
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: "Search country",
                        prefixIcon:
                            const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredCountries = countries
                              .where(
                                (country) => country
                                    .toLowerCase()
                                    .contains(
                                      value.toLowerCase(),
                                    ),
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount:
                            filteredCountries.length,
                        itemBuilder:
                            (context, index) {
                          final country =
                              filteredCountries[index];

                          return ListTile(
                            title: Text(country),
                            trailing: Text(
                              countryPhoneCodes[
                                      country] ??
                                  '',
                            ),
                            onTap: () {
                              setState(() {
                                selectedCountry =
                                    country;

                                selectedPhoneCode =
                                    countryPhoneCodes[
                                            country] ??
                                        selectedPhoneCode;
                              });

                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _zipController.dispose();

    super.dispose();
  }

  String? validateText(
    String? value,
    String fieldName, {
    bool required = false,
    int min = 2,
    int max = 80,
  }) {
    final text = value?.trim() ?? '';

    if (required && text.isEmpty) {
      return "$fieldName is required";
    }

    if (text.isNotEmpty &&
        text.length < min) {
      return "$fieldName is too short";
    }

    if (text.length > max) {
      return "$fieldName is too long";
    }

    if (hasInvalidChars(text)) {
      return "$fieldName contains invalid characters";
    }

    return null;
  }

  String? validatePhone(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return "Phone number is required";
    }

    if (!RegExp(r'^(05\d{8}|5\d{8})$').hasMatch(text)) {
      return "Enter a valid phone number";
    }

    return null;
  }

  String? validateZip(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    if (!RegExp(r'^[A-Za-z0-9 -]{3,12}$')
        .hasMatch(text)) {
      return "Invalid zip code";
    }

    return null;
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType =
        TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 6),

        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLength: 120,

          decoration: InputDecoration(
            counterText: "",
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey[400]),

            filled: true,
            fillColor: Colors.grey[50],

            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),

            focusedBorder:
                const OutlineInputBorder(
              borderSide: BorderSide(
                color: Color(0xFF0D1A3A),
              ),
            ),

            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryPicker() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          "Country",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 6),

        GestureDetector(
          onTap: loadingCountries
              ? null
              : showCountrySearchDialog,
          child: Container(
            height: 56,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
            ),

            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),

            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCountry ?? "Select",
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          selectedCountry == null
                              ? Colors.grey[500]
                              : Colors.black,
                      fontSize: 15,
                    ),
                  ),
                ),

                loadingCountries
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.keyboard_arrow_down,
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    final phoneCodes =
        countryPhoneCodes.values.toSet().toList()
          ..sort();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          "Phone Number",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 6),

        Row(
          children: [
            SizedBox(
              width: 105,

              child: DropdownButtonFormField<
                  String>(
                initialValue: phoneCodes
                        .contains(selectedPhoneCode)
                    ? selectedPhoneCode
                    : null,

                isExpanded: true,
                hint: const Text("+Code"),

                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),

                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color:
                          Colors.grey.shade200,
                    ),
                  ),

                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),

                items: phoneCodes.map((code) {
                  return DropdownMenuItem(
                    value: code,
                    child: Text(code),
                  );
                }).toList(),

                onChanged: (value) {
                  setState(
                    () => selectedPhoneCode =
                        value,
                  );
                },
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType:
                    TextInputType.phone,
                validator: validatePhone,
                maxLength: 15,

                decoration: InputDecoration(
                  counterText: "",
                  hintText:
                      "Enter phone number",

                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                  ),

                  filled: true,
                  fillColor: Colors.grey[50],

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                            12),
                  ),

                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                            12),
                    borderSide: BorderSide(
                      color:
                          Colors.grey.shade200,
                    ),
                  ),

                  focusedBorder:
                      const OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          Color(0xFF0D1A3A),
                    ),
                  ),

                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidImage =
        profileImageUrl != null &&
            profileImageUrl!.startsWith(
              'http',
            );

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          "Settings",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),

        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () =>
              Navigator.pop(context, true),
        ),
      ),

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.all(20),

              child: Form(
                key: _formKey,

                child: Column(
                  children: [
                    GestureDetector(
                      onTap: pickAndUploadImage,

                      child: Stack(
                        alignment:
                            Alignment.bottomRight,

                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                Colors.grey[100],

                            backgroundImage:
                                hasValidImage
                                    ? NetworkImage(
                                        profileImageUrl!,
                                      )
                                    : null,

                            child: !hasValidImage
                                ? const Icon(
                                    Icons
                                        .person_outline,
                                    size: 50,
                                    color:
                                        Colors.grey,
                                  )
                                : null,
                          ),

                          Container(
                            padding:
                                const EdgeInsets.all(
                                    6),

                            decoration:
                                const BoxDecoration(
                              color:
                                  Color(0xFF0D1A3A),
                              shape:
                                  BoxShape.circle,
                            ),

                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    _buildField(
                      label: "Company Name",
                      hint: "Enter company name",
                      controller:
                          _companyController,

                      validator: (v) =>
                          validateText(
                        v,
                        "Company name",
                        required: true,
                        min: 2,
                        max: 80,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildPhoneField(),

                    const SizedBox(height: 16),

                    _buildField(
                      label: "Address",
                      hint: "Enter address",
                      controller:
                          _addressController,

                      validator: (v) =>
                          validateText(
                        v,
                        "Address",
                        required: true,
                        min: 3,
                        max: 120,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child:
                              _buildCountryPicker(),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: _buildField(
                            label: "State",
                            hint: "Enter state",
                            controller:
                                _stateController,

                            validator: (v) =>
                                validateText(
                              v,
                              "State",
                              required: true,
                              min: 2,
                              max: 60,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: "City",
                            hint: "Enter city",
                            controller:
                                _cityController,

                            validator: (v) =>
                                validateText(
                              v,
                              "City",
                              required: true,
                              min: 2,
                              max: 60,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: _buildField(
                            label: "Zip Code",
                            hint:
                                "Enter zip code",
                            controller:
                                _zipController,
                            keyboardType:
                                TextInputType
                                    .text,
                            validator:
                                validateZip,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 50,

                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : saveSettings,

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(
                                  0xFF0D1A3A),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                                        12),
                          ),
                        ),

                        child: isSaving
                            ? const CircularProgressIndicator(
                                color:
                                    Colors.white,
                              )
                            : const Text(
                                "Save",
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white,
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