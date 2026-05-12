import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EngEnvironmentPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const EngEnvironmentPage({super.key, required this.project});

  @override
  State<EngEnvironmentPage> createState() => _EngEnvironmentPageState();
}

class _EngEnvironmentPageState extends State<EngEnvironmentPage> {
  static const Color primaryColor = Color(0xff0d1b46);
  static const Color greenColor = Color(0xff18b26b);
  static const Color orangeColor = Color(0xffff9800);
  static const Color redColor = Color(0xffef4444);
  static const Color blueColor = Color(0xff1e9cf0);

  bool isLoading = true;
  String? errorMessage;

  double? temperature;
  double? humidity;
  double? windSpeed;
  double? rain;
  String lastUpdate = '';

  double get latitude {
    final value =
        widget.project['latitude'] ??
        widget.project['lat'] ??
        widget.project['project_latitude'];

    return double.tryParse(value?.toString() ?? '') ?? 21.543333;
  }

  double get longitude {
    final value =
        widget.project['longitude'] ??
        widget.project['lng'] ??
        widget.project['project_longitude'];

    return double.tryParse(value?.toString() ?? '') ?? 39.172779;
  }

  String get projectName {
    final name = widget.project['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Project Site' : name;
  }

  double get tempValue => temperature ?? 0;
  double get humidityValue => humidity ?? 0;
  double get windValue => windSpeed ?? 0;
  double get rainValue => rain ?? 0;

  @override
  void initState() {
    super.initState();

    // Delay one frame so the page renders first, then API loads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadWeatherApi();
    });
  }

  Future<void> loadWeatherApi() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,rain'
        '&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Weather API status code: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final current = decoded['current'];

      if (current == null || current is! Map) {
        throw Exception('Weather API returned empty current data');
      }

      if (!mounted) return;

      setState(() {
        temperature = toDouble(current['temperature_2m']);
        humidity = toDouble(current['relative_humidity_2m']);
        windSpeed = toDouble(current['wind_speed_10m']);
        rain = toDouble(current['rain']);
        lastUpdate = current['time']?.toString() ?? '';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Unable to load Weather API data.\nCheck internet connection, Android INTERNET permission, and project location.';
      });

      debugPrint('Environment weather API error: $e');
    }
  }

  double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get environmentStatus {
    if (rainValue > 0 || tempValue >= 42 || windValue >= 35) {
      return 'High Risk';
    }

    if (tempValue >= 36 || humidityValue >= 80 || windValue >= 28) {
      return 'Needs Attention';
    }

    return 'Stable';
  }

  Color get statusColor {
    if (environmentStatus == 'High Risk') return redColor;
    if (environmentStatus == 'Needs Attention') return orangeColor;
    return greenColor;
  }

  IconData get statusIcon {
    if (environmentStatus == 'High Risk') return Icons.warning_amber_rounded;
    if (environmentStatus == 'Needs Attention') {
      return Icons.info_outline_rounded;
    }
    return Icons.verified_rounded;
  }

  String get statusDescription {
    if (rainValue > 0) {
      return 'Rain is detected at the construction site. Outdoor activities may be affected.';
    }

    if (tempValue >= 42) {
      return 'Extreme heat may affect worker safety and productivity.';
    }

    if (windValue >= 35) {
      return 'Strong wind may affect lifting and site operations.';
    }

    if (tempValue >= 36) {
      return 'High temperature requires close monitoring.';
    }

    if (humidityValue >= 80) {
      return 'High humidity may affect worker comfort and site conditions.';
    }

    if (windValue >= 28) {
      return 'Moderate wind requires monitoring.';
    }

    return 'Weather conditions are currently suitable for site operations.';
  }

  String get recommendation {
    if (rainValue > 0) {
      return 'Review outdoor activities and protect exposed materials.';
    }

    if (tempValue >= 42) {
      return 'Reduce outdoor exposure and increase hydration breaks.';
    }

    if (windValue >= 35) {
      return 'Avoid crane or lifting operations until wind speed decreases.';
    }

    if (tempValue >= 36 || humidityValue >= 80) {
      return 'Monitor workers closely and schedule rest breaks.';
    }

    if (windValue >= 28) {
      return 'Continue work with wind monitoring.';
    }

    return 'Continue normal monitoring.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: AppBar(
        title: const Text(
          'Environment Monitoring',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loadWeatherApi,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadWeatherApi,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              if (isLoading) buildLoadingCard(),
              if (!isLoading && errorMessage != null) buildErrorCard(),
              if (!isLoading && errorMessage == null) ...[
                buildHeroCard(),
                const SizedBox(height: 12),
                buildLocationInfoCard(),
                const SizedBox(height: 10),
                buildWeatherGrid(),
                const SizedBox(height: 10),
                buildAnalysisCard(),
                const SizedBox(height: 10),
                buildRecommendationCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(),
      child: const Column(
        children: [
          SizedBox(height: 8),
          CircularProgressIndicator(),
          SizedBox(height: 18),
          Text(
            'Loading live weather data...',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Reading project location from Weather API',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.red),
          const SizedBox(height: 14),
          const Text(
            'Weather data is unavailable',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Location: ${widget.project['location']?.toString() ?? 'Construction Site'}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: loadWeatherApi,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, statusColor.withOpacity(.92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white.withOpacity(.17),
                child: Icon(statusIcon, color: Colors.white, size: 30),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Open-Meteo API',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            environmentStatus,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 31,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            projectName,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Text(
            statusDescription,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
          if (lastUpdate.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Last update: $lastUpdate',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget buildLocationInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.project['location']?.toString() ?? 'Construction Site',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWeatherGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Weather Data',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: weatherCard(
                'Temperature',
                '${tempValue.toStringAsFixed(1)}°C',
                Icons.thermostat_rounded,
                Colors.deepOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: weatherCard(
                'Humidity',
                '${humidityValue.toStringAsFixed(0)}%',
                Icons.water_drop_rounded,
                Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: weatherCard(
                'Wind Speed',
                '${windValue.toStringAsFixed(1)} km/h',
                Icons.air_rounded,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: weatherCard(
                'Rain',
                '${rainValue.toStringAsFixed(1)} mm',
                Icons.water_rounded,
                Colors.blueGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.analytics_outlined, 'Environment Analysis', blueColor),
          const SizedBox(height: 16),
          analysisRow(
            'Heat condition',
            tempValue >= 42
                ? 'Extreme heat'
                : tempValue >= 36
                    ? 'High temperature'
                    : 'Normal',
            tempValue >= 36 ? orangeColor : greenColor,
          ),
          analysisRow(
            'Humidity condition',
            humidityValue >= 80 ? 'High humidity' : 'Stable',
            humidityValue >= 80 ? orangeColor : greenColor,
          ),
          analysisRow(
            'Wind condition',
            windValue >= 35
                ? 'Strong wind'
                : windValue >= 28
                    ? 'Moderate wind'
                    : 'Normal',
            windValue >= 28 ? orangeColor : greenColor,
          ),
          analysisRow(
            'Rain condition',
            rainValue > 0 ? 'Rain detected' : 'No rain',
            rainValue > 0 ? redColor : greenColor,
          ),
        ],
      ),
    );
  }

  Widget buildRecommendationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.task_alt_rounded, 'Recommended Action', statusColor),
          const SizedBox(height: 12),
          Text(
            recommendation,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'All values in this page come from the live Weather API based on the project location.',
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.4,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget weatherCard(String title, String value, IconData icon, Color color) {
    return Container(
      height: 158,
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(.12),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget titleRow(IconData icon, String title, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withOpacity(.12),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget analysisRow(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffeeeeee)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}
