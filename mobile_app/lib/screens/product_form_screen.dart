import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product; // null = Add mode, non-null = Edit mode
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final InventoryService _inventoryService = InventoryService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _weightController;
  late TextEditingController _unitController;

  bool _isSubmitting = false;
  bool get _isEditMode => widget.product != null;

  // Custom Colors
  final Color primaryBlue = const Color(0xFF3B82F6);
  final Color textDark = const Color(0xFF1F2937);
  final Color textLight = const Color(0xFF6B7280);
  final Color borderLight = const Color(0xFFE5E7EB);
  final Color bgLight = const Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(
      text: p?['ProductName']?.toString() ?? '',
    );
    _skuController = TextEditingController(text: p?['SKU']?.toString() ?? '');
    _priceController = TextEditingController(
      text: p?['Price']?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: (p?['Weight'] ?? p?['weight'] ?? '').toString(),
    );
    _unitController = TextEditingController(
      text: p?['Unit']?.toString() ?? 'box',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Use replaceAll(',', '.') to handle locale specific decimal formats
    final priceStr = _priceController.text.trim().replaceAll(',', '.');
    final weightStr = _weightController.text.trim().replaceAll(',', '.');

    final data = {
      'ProductName': _nameController.text.trim(),
      'SKU': _skuController.text.trim(),
      'Price': double.tryParse(priceStr) ?? 0.0,
      'Weight': double.tryParse(weightStr) ?? 0.0,
      'Unit': _unitController.text.trim(),
    };

    try {
      if (_isEditMode) {
        final productId =
            widget.product!['ProductID'] ??
            widget.product!['productId'] ??
            widget.product!['id'];
        await _inventoryService.updateProduct(productId, data);
      } else {
        await _inventoryService.createProduct(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Product updated successfully'
                : 'Product created successfully',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $errorMsg'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _customInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textLight, fontSize: 14),
      prefixIcon: Icon(icon, color: textLight, size: 20),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Product' : 'Add New Product',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textDark),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderLight, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Basic Info Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.015),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Basic Information',
                              Icons.info_outline,
                            ),
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _customInputDecoration(
                                'Product Name',
                                Icons.label_outline,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _skuController,
                              style: TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _customInputDecoration(
                                'SKU',
                                Icons.qr_code_2,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Pricing & Inventory Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.015),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Pricing & Inventory',
                              Icons.inventory_2_outlined,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    style: TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: _customInputDecoration(
                                      'Price (LKR)',
                                      Icons.attach_money,
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _weightController,
                                    style: TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: _customInputDecoration(
                                      'Weight (kg)',
                                      Icons.scale_outlined,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _unitController,
                              style: TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _customInputDecoration(
                                'Unit Type',
                                Icons.category_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Save Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: borderLight)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isEditMode ? 'Save Changes' : 'Create Product',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
