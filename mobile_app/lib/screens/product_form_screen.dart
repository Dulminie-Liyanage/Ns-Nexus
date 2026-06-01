import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/inventory_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product; // null = create, non-null = edit
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = InventoryService();

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _weight;
  late final TextEditingController _stock;
  bool _isAvailable = true;
  bool _loading = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?['ProductName']?.toString() ?? '');
    _sku = TextEditingController(text: p?['SKU']?.toString() ?? '');
    _unit = TextEditingController(text: p?['Unit']?.toString() ?? '');
    _price = TextEditingController(text: p?['Price']?.toString() ?? '');
    _weight = TextEditingController(text: p?['Weight']?.toString() ?? '');
    // Handle null StockLevel gracefully
    final stock = p?['StockLevel'];
    _stock = TextEditingController(
      text: stock != null ? stock.toString() : '0',
    );
    _isAvailable = (p?['IsAvailable'] == 1 || p?['IsAvailable'] == true);
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _unit.dispose();
    _price.dispose();
    _weight.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await _svc.updateProduct(
          productId: widget.product!['ProductID'],
          productName: _name.text.trim(),
          sku: _sku.text.trim(),
          unit: _unit.text.trim(),
          price: double.tryParse(_price.text) ?? 0,
          weight: double.tryParse(_weight.text) ?? 0,
          stockLevel: int.tryParse(_stock.text) ?? 0,
          isAvailable: _isAvailable ? 1 : 0,
        );
      } else {
        await _svc.createProduct(
          productName: _name.text.trim(),
          sku: _sku.text.trim(),
          unit: _unit.text.trim(),
          price: double.tryParse(_price.text) ?? 0,
          weight: double.tryParse(_weight.text) ?? 0,
          stockLevel: int.tryParse(_stock.text) ?? 0,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Product' : 'Add Product',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _card(
                children: [
                  const _SectionTitle('Product Info'),
                  _field(
                    _name,
                    'Product Name *',
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _sku,
                          'SKU *',
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _unit,
                          'Unit (kg/box/pack)',
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _card(
                children: [
                  const _SectionTitle('Pricing & Weight'),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _price,
                          'Price (LKR) *',
                          keyboard: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _weight,
                          'Weight (kg) *',
                          keyboard: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _card(
                children: [
                  const _SectionTitle('Stock'),
                  _field(
                    _stock,
                    'Stock Level',
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isAvailable
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isAvailable
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isAvailable
                              ? Icons.check_circle_outline
                              : Icons.remove_circle_outline,
                          color: _isAvailable
                              ? Colors.green.shade600
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available to Retailers',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: _isAvailable
                                      ? Colors.green.shade800
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                _isAvailable
                                    ? 'Visible in retailer order screen'
                                    : 'Hidden from retailer order screen',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isAvailable,
                          activeColor: Colors.green.shade600,
                          onChanged: (v) => setState(() => _isAvailable = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _isEdit ? 'Save Changes' : 'Add Product',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(5),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    ),
  );
}
