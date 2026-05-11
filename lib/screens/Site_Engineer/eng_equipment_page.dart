import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:senior_project/screens/equipment_tracking_api_service.dart';
import 'package:senior_project/services/supabase_service.dart';

class EngEquipmentPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const EngEquipmentPage({super.key, required this.project});

  @override
  State<EngEquipmentPage> createState() => _EngEquipmentPageState();
}

class _EngEquipmentPageState extends State<EngEquipmentPage> {
  final SupabaseService supabaseService = SupabaseService();
  final EquipmentTrackingApiService trackingApiService =
      EquipmentTrackingApiService();
  final supabase = Supabase.instance.client;

  static const Color primaryColor = Color(0xff0d1b46);
  static const Color greenColor = Color(0xff18b26b);
  static const Color purpleColor = Color(0xff6c63ff);
  static const Color borderColor = Color(0xffeeeeee);
  static const Color lightTextColor = Color(0xff8f8f8f);

  bool isLoading = true;
  bool isMapLoading = true;

  String search = '';

  List<Map<String, dynamic>> equipment = [];
  List<EquipmentLocation> liveLocations = [];

  GoogleMapController? mapController;

  final Map<String, BitmapDescriptor> markerIcons = {};

  String get projectId => widget.project['id']?.toString() ?? '';

  String get projectName {
    return cleanText(widget.project['name']).isEmpty
        ? 'Project'
        : cleanText(widget.project['name']);
  }

  double? get projectLatitude {
    return double.tryParse(widget.project['latitude']?.toString() ?? '');
  }

  double? get projectLongitude {
    return double.tryParse(widget.project['longitude']?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();
    loadMarkerIcons();
    loadAll();
  }

  String cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  Future<void> loadAll() async {
    setState(() {
      isLoading = true;
      isMapLoading = true;
    });

    await loadEquipment();
    await loadLiveEquipmentLocations();

    if (mounted) {
      setState(() {
        isLoading = false;
        isMapLoading = false;
      });
    }
  }

  Future<void> loadEquipment() async {
    try {
      final result = await supabaseService.getProjectEquipment(projectId);

      if (mounted) {
        setState(() {
          equipment = result;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load equipment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> loadLiveEquipmentLocations() async {
    try {
      final result = await trackingApiService.getLiveEquipmentLocations(
        projectId,
        latitude: projectLatitude,
        longitude: projectLongitude,
      );

      final projectEquipmentNames =
          equipment.map((item) {
            return cleanText(item['equipment_catalog']?['name']).toLowerCase();
          }).toSet();

      final filteredResult =
          result.where((liveItem) {
            return projectEquipmentNames.contains(
              liveItem.name.trim().toLowerCase(),
            );
          }).toList();

      if (mounted) {
        setState(() {
          liveLocations = filteredResult;
        });
      }
    } catch (e) {
      debugPrint('Equipment API error: $e');

      if (mounted) {
        setState(() {
          liveLocations = [];
        });
      }
    }
  }

  Future<void> loadMarkerIcons() async {
    markerIcons['excavator'] = await createIconMarker(
      Icons.construction,
      Colors.orange,
    );

    markerIcons['truck'] = await createIconMarker(
      Icons.local_shipping,
      Colors.blue,
    );

    markerIcons['crane'] = await createIconMarker(
      Icons.precision_manufacturing,
      Colors.deepPurple,
    );

    markerIcons['loader'] = await createIconMarker(
      Icons.agriculture,
      Colors.green,
    );

    markerIcons['default'] = await createIconMarker(
      Icons.engineering,
      primaryColor,
    );

    if (mounted) {
      setState(() {});
    }
  }

  BitmapDescriptor getEquipmentMarkerIcon(String type) {
    final value = type.toLowerCase();

    if (value.contains('excavator')) {
      return markerIcons['excavator'] ?? BitmapDescriptor.defaultMarker;
    }

    if (value.contains('truck')) {
      return markerIcons['truck'] ?? BitmapDescriptor.defaultMarker;
    }

    if (value.contains('crane')) {
      return markerIcons['crane'] ?? BitmapDescriptor.defaultMarker;
    }

    if (value.contains('loader')) {
      return markerIcons['loader'] ?? BitmapDescriptor.defaultMarker;
    }

    return markerIcons['default'] ?? BitmapDescriptor.defaultMarker;
  }

  Future<BitmapDescriptor> createIconMarker(
    IconData icon,
    Color iconColor,
  ) async {
    const double size = 120;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    final shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 10, 100, 80),
      const Radius.circular(18),
    );

    canvas.drawRRect(rrect.shift(const Offset(0, 4)), shadowPaint);
    canvas.drawRRect(rrect, bgPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 54,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: iconColor,
      ),
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, 23));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'working':
      case 'good':
        return greenColor;

      case 'paused':
      case 'pausing':
      case 'maintenance':
        return Colors.orange;

      case 'damaged':
      case 'not working':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get filtered {
    return equipment.where((item) {
      return cleanText(
        item['equipment_catalog']?['name'],
      ).toLowerCase().contains(search.toLowerCase());
    }).toList();
  }

  Future<void> requestMore(Map<String, dynamic> item) async {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();

    final catalog = item['equipment_catalog'] ?? {};

    final itemName =
        cleanText(catalog['name']).isEmpty
            ? 'Equipment'
            : cleanText(catalog['name']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Request more $itemName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Example: Please update the equipment stock',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final quantity = int.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
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
              ? 'Site engineer'
              : cleanText(profile?['full_name']);

      await supabase.from('resource_requests').insert({
        'project_id': projectId,
        'requested_by': user?.id,
        'request_type': 'equipment',
        'item_name': itemName,
        'quantity': quantity,
        'note':
            noteController.text.trim().isEmpty
                ? 'The site engineer "$engineerName" requested $quantity more $itemName. Please update the stock.'
                : noteController.text.trim(),
        'status': 'pending',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent to manager ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget topRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Text(
            'Equipment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget liveMap() {
    if (liveLocations.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            isMapLoading
                ? 'Loading equipment API...'
                : 'No live equipment API data',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final center = LatLng(
      liveLocations.first.latitude,
      liveLocations.first.longitude,
    );

    final markers =
        liveLocations
            .map(
              (equipment) => Marker(
                markerId: MarkerId(equipment.equipmentId),
                position: LatLng(equipment.latitude, equipment.longitude),
                icon: getEquipmentMarkerIcon(equipment.type),
                infoWindow: InfoWindow(
                  title: equipment.name,
                  snippet: '${equipment.status} • ${equipment.type}',
                ),
                onTap: () => sheet(equipment),
              ),
            )
            .toSet();

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: center,
          zoom: 18,
          tilt: 45,
          bearing: 20,
        ),
        onMapCreated: (controller) {
          mapController = controller;

          Future.delayed(const Duration(milliseconds: 400), () {
            mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: center,
                  zoom: 18.5,
                  tilt: 55,
                  bearing: 30,
                ),
              ),
            );
          });
        },
        markers: markers,
        mapType: MapType.satellite,
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: true,
        buildingsEnabled: true,
        trafficEnabled: false,
      ),
    );
  }

  void sheet(EquipmentLocation equipment) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child:
                        equipment.imageUrl != null &&
                                equipment.imageUrl!.startsWith('http')
                            ? Image.network(
                              equipment.imageUrl!,
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            )
                            : Container(
                              width: 84,
                              height: 84,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.precision_manufacturing,
                                color: Colors.grey,
                              ),
                            ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipment.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          equipment.type,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Status: ${equipment.status}',
                          style: TextStyle(
                            color: statusColor(equipment.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fuel: ${equipment.fuelLevel?.toString() ?? '-'}%',
                        ),
                        Text('Engine: ${equipment.engineStatus ?? '-'}'),
                        if (equipment.maintenanceAlert)
                          const Text(
                            'Maintenance alert detected',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text('Lat: ${equipment.latitude.toStringAsFixed(5)}'),
                        Text('Lng: ${equipment.longitude.toStringAsFixed(5)}'),
                      ],
                    ),
                  ),
                ],
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
            setState(() {
              search = value;
            });
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
    final catalog = item['equipment_catalog'] ?? {};

    final name =
        cleanText(catalog['name']).isEmpty
            ? 'Equipment'
            : cleanText(catalog['name']);

    final type = cleanText(catalog['type']);

    final imageUrl = cleanText(catalog['image_url']);

    final status =
        cleanText(item['condition_status']).isEmpty
            ? 'Working'
            : cleanText(item['condition_status']);

    final challan =
        cleanText(item['challan_no']).isEmpty
            ? '-'
            : cleanText(item['challan_no']);

    final available = item['available_quantity'] ?? 0;
    final required = item['required_quantity'] ?? 0;

    final date =
        cleanText(item['last_update']).isEmpty
            ? 'Today'
            : cleanText(item['last_update']).split('T').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child:
                imageUrl.startsWith('http')
                    ? Image.network(
                      imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    )
                    : Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.precision_manufacturing,
                        color: Colors.grey,
                        size: 22,
                      ),
                    ),
          ),
          const SizedBox(width: 11),
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
                const SizedBox(height: 6),
                Text(
                  type.isEmpty
                      ? 'Challan No. $challan'
                      : '$type • Challan No. $challan',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  'Required: $required',
                  style: const TextStyle(fontSize: 10, color: lightTextColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Date: $date',
                style: const TextStyle(fontSize: 10, color: lightTextColor),
              ),
              const SizedBox(height: 7),
              Text(
                '+$available Numbers',
                style: const TextStyle(
                  color: purpleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
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
            const SizedBox(height: 14),
            topRow(),
            const SizedBox(height: 12),
            liveMap(),
            searchBox(),
            const SizedBox(height: 12),
            Expanded(
              child:
                  filtered.isEmpty
                      ? const Center(
                        child: Text(
                          'No equipment added yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : RefreshIndicator(
                        onRefresh: loadAll,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
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
