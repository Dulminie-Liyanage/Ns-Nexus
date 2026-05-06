import 'package:flutter/material.dart';
import '../services/inventory_service.dart';
import 'product_form_screen.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final InventoryService _service = InventoryService();
  late Future<List<dynamic>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _service.fetchProducts();
  }

  Future<void> _toggleStatus(dynamic productId, int currentAvailability) async {
    final newAvailability = currentAvailability == 1 ? 0 : 1;
    try {
      await _service.toggleProductStatus(productId, newAvailability);
      setState(() {
        _productsFuture = _service.fetchProducts();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  // Colors matching the UI
  final Color primaryBlue = const Color(0xFF3B82F6);
  final Color textDark = const Color(0xFF1F2937);
  final Color textLight = const Color(0xFF6B7280);
  final Color borderLight = const Color(0xFFE5E7EB);

  Widget _buildAvailabilityToggle(dynamic p) {
    bool isAvailable = p['IsAvailable'] == 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isAvailable ? 'In Stock' : 'Sold Out',
          style: TextStyle(
            color: isAvailable ? const Color(0xFF059669) : const Color(0xFFDC2626),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: isAvailable,
            activeColor: const Color(0xFF059669),
            onChanged: (bool value) {
              _toggleStatus(p['ProductID'], p['IsAvailable'] ?? 1);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Softer background for cards
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;

          return Padding(
            padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Controls
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      Text(
                        'Products',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!isMobile)
                            _buildTopControl('Showing', '10', Icons.keyboard_arrow_down),
                          _buildTopControlBtn(Icons.filter_alt_outlined, isMobile ? null : 'Filter'),
                          _buildTopControlBtn(Icons.upload_outlined, isMobile ? null : 'Export'),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                              );
                              if (result == true) {
                                setState(() {
                                  _productsFuture = _service.fetchProducts();
                                });
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(isMobile ? 'Add' : 'Add New Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isMobile) const SizedBox(height: 8),

                // Table / Mobile List Body
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: _productsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: primaryBlue));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                      }

                      final products = snapshot.data ?? [];
                      if (products.isEmpty) {
                        return const Center(child: Text('No products found.'));
                      }

                      if (isMobile) {
                        return ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildMobileProductCard(products[index]);
                          },
                        );
                      } else {
                        return _buildDesktopTable(products);
                      }
                    },
                  ),
                ),

                // Pagination Bottom
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 16,
                    children: [
                      TextButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.chevron_left, color: textLight),
                        label: Text('Previous', style: TextStyle(color: textLight)),
                      ),
                      if (!isMobile)
                        Wrap(
                          spacing: 4,
                          children: [
                            _pageNumber('1', true),
                            _pageNumber('2', false),
                            _pageNumber('3', false),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text('...', style: TextStyle(color: textLight)),
                            ),
                            _pageNumber('10', false),
                          ],
                        ),
                      TextButton(
                        onPressed: () {},
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Next', style: TextStyle(color: textDark)),
                            Icon(Icons.chevron_right, color: textDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileProductCard(dynamic p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: Colors.blueGrey[50],
                        child: Icon(Icons.image_outlined, color: Colors.blueGrey[300]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['ProductName']?.toString() ?? 'Unknown Product',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p['SKU']?.toString() ?? '#ID${p['ProductID']}',
                            style: TextStyle(fontSize: 13, color: textLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildActionMenu(p),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMobileInfoItem('Price', '\$${(double.tryParse(p['Price']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}'),
                _buildMobileInfoItem('Unit Type', p['Unit']?.toString() ?? 'N/A'),
                _buildMobileInfoItem('Type', p['Type']?.toString() ?? 'Dessert'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status:', style: TextStyle(color: textLight, fontSize: 13)),
              _buildAvailabilityToggle(p),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMobileInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textLight, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDesktopTable(List<dynamic> products) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderLight)),
              color: const Color(0xFFF9FAFB),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _headerText('Product Name')),
                Expanded(flex: 2, child: _headerText('Product ID')),
                Expanded(flex: 2, child: _headerText('Price')),
                Expanded(flex: 2, child: _headerText('Type')),
                Expanded(flex: 2, child: _headerText('Status')),
                Expanded(flex: 1, child: _headerText('Action')),
              ],
            ),
          ),
          // Body
          Expanded(
            child: ListView.separated(
              itemCount: products.length,
              separatorBuilder: (context, index) => Divider(color: borderLight, height: 1),
              itemBuilder: (context, index) {
                final p = products[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    children: [
                      // Product Name
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey[200],
                                child: Icon(Icons.image_outlined, color: Colors.grey[400]),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p['ProductName']?.toString() ?? 'N/A',
                                style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(p['SKU']?.toString() ?? '#ID${p['ProductID']}', style: TextStyle(color: textLight)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('\$${(double.tryParse(p['Price']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}', style: TextStyle(color: textLight)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(p['Type']?.toString() ?? 'Dessert', style: TextStyle(color: textLight)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildAvailabilityToggle(p),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildActionMenu(p),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(dynamic p) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Colors.grey),
      onSelected: (value) {
        if (value == 'toggle') {
          _toggleStatus(p['ProductID'], p['IsAvailable'] ?? 1);
        } else if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
          ).then((result) {
            if (result == true) {
              setState(() {
                _productsFuture = _service.fetchProducts();
              });
            }
          });
        }
      },
      itemBuilder: (context) {
        final isAvailable = p['IsAvailable'] == 1;
        return [
          PopupMenuItem(
            value: 'toggle',
            child: Text(isAvailable ? 'Deactivate' : 'Activate'),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Text('Edit'),
          ),
        ];
      },
    );
  }

  Widget _headerText(String title) {
    return Row(
      children: [
        Text(title, style: TextStyle(color: textLight, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Icon(Icons.unfold_more, size: 14, color: Colors.grey[400]),
      ],
    );
  }

  Widget _buildTopControl(String prefix, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(prefix, style: TextStyle(color: textLight, fontSize: 13)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(color: textDark, fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: textLight),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopControlBtn(IconData icon, String? label, {VoidCallback? onPressed}) {
    return OutlinedButton(
      onPressed: onPressed ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${label ?? 'Action'} is not fully implemented yet')),
        );
      },
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: label == null ? 12 : 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: borderLight),
        foregroundColor: textDark,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ]
        ],
      ),
    );
  }

  Widget _pageNumber(String number, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? primaryBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        number,
        style: TextStyle(
          color: isActive ? Colors.white : textDark,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}

