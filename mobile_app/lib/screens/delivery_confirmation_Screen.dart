import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';
import '../services/analiytics_service.dart';
import '../services/driver_service.dart';
import '../services/order_service.dart';

class DeliveryConfirmationScreen extends StatefulWidget {
  final DeliveryStop stop;
  const DeliveryConfirmationScreen({super.key, required this.stop});

  @override
  State<DeliveryConfirmationScreen> createState() => _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState extends State<DeliveryConfirmationScreen> {
  final _svc = AnalyticsService();
  final _driverSvc = DriverService();
  final _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: const Color(0xFF0056B3),
    exportBackgroundColor: Colors.white,
  );

  File? _photo;
  String? _photoBase64;
  Position? _position;
  bool _submitting = false;
  bool _locationFetched = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'Location services disabled');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _position = pos;
        _locationFetched = true;
      });
    } catch (e) {
      setState(() => _locationError = 'Location unavailable');
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1024,
    );
    if (img == null) return;
    final file = File(img.path);
    final bytes = await file.readAsBytes();
    setState(() {
      _photo = file;
      _photoBase64 = base64Encode(bytes);
    });
  }

  Future<void> _submit() async {
    if (_sigController.isEmpty) {
      _snack('Please capture the recipient\'s signature.', isError: true);
      return;
    }
    if (_photo == null) {
      _snack('Please take a photo as proof of delivery.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      // Export signature as base64 PNG
      final sigBytes = await _sigController.toPngBytes();
      final sigBase64 = sigBytes != null ? base64Encode(sigBytes) : null;

      await _svc.confirmDelivery(
        orderId: widget.stop.orderId,
        signature: sigBase64,
        photo: _photoBase64,
        lat: _position?.latitude,
        lng: _position?.longitude,
      );

      // Set driver available immediately
      await _driverSvc.updateStatus('AVAILABLE');

      if (!mounted) return;
      Navigator.pop(context, true); // true = success, caller reloads
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Delivery confirmed successfully!'),
          ]),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Confirm Delivery',
            style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Delivery info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE6EFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0056B3).withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.store_outlined, color: Color(0xFF0056B3), size: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.stop.retailerName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B))),
                Text('Order #${widget.stop.orderId}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0056B3), fontWeight: FontWeight.w600)),
                Text(widget.stop.address,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // GPS status
          _sectionLabel('GPS Timestamp'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Icon(
                _locationFetched ? Icons.location_on : Icons.location_off,
                color: _locationFetched ? Colors.green.shade600 : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _locationFetched
                    ? 'Lat: ${_position!.latitude.toStringAsFixed(5)}, Lng: ${_position!.longitude.toStringAsFixed(5)}'
                    : _locationError ?? 'Fetching location...',
                style: TextStyle(
                  fontSize: 13,
                  color: _locationFetched ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              )),
              if (!_locationFetched && _locationError == null)
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ),
          const SizedBox(height: 24),

          // Signature pad
          _sectionLabel('Recipient Signature *'),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _sigController.isEmpty
                    ? Colors.grey.shade300
                    : const Color(0xFF0056B3).withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Signature(
                controller: _sigController,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Ask recipient to sign above',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _sigController.clear()),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            ),
          ]),
          const SizedBox(height: 24),

          // Photo proof
          _sectionLabel('Photo Proof *'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _photo != null
                      ? Colors.green.shade300
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: _photo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_photo!, fit: BoxFit.cover),
                    )
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text('Tap to take photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                      Text('Photo of delivered goods / recipient', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ]),
            ),
          ),
          if (_photo != null) ...[ 
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickPhoto,
              child: Text('Retake photo',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade600, decoration: TextDecoration.underline)),
            ),
          ],
          const SizedBox(height: 32),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056B3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.verified_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Confirm Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));
}