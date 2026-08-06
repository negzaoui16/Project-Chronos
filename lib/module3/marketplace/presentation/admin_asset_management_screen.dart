import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_bloc.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_event.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_state.dart';

class AdminAssetManagementScreen extends StatefulWidget {
  const AdminAssetManagementScreen({super.key});

  @override
  State<AdminAssetManagementScreen> createState() => _AdminAssetManagementScreenState();
}

class _AdminAssetManagementScreenState extends State<AdminAssetManagementScreen> {

  @override
  void initState() {
    super.initState();
    // Fetch real assets from Neon DB on screen load
    context.read<MarketplaceBloc>().add(FetchMarketplaceAssetsEvent());
  }

  void _showAddAssetDialog(BuildContext context) {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final maxDaysController = TextEditingController(text: '3');
    String selectedCategory = 'Hardware';
    String? pickedImagePath;
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDialogImage() async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (picked != null) {
                  setDialogState(() {
                    pickedImagePath = picked.path;
                  });
                }
              } catch (_) {}
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Add New Asset',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B1326),
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Selector
                      GestureDetector(
                        onTap: pickDialogImage,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: pickedImagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(pickedImagePath!), fit: BoxFit.cover),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, color: Color(0xFF8083FF), size: 32),
                                    SizedBox(height: 8),
                                    Text(
                                      'Upload Asset Image',
                                      style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Asset Name
                      const Text(
                        'ASSET NAME',
                        style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Meta Quest 3 VR',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF8083FF), width: 1.5),
                          ),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter asset name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Category
                      const Text(
                        'CATEGORY',
                        style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        items: ['Hardware', 'Labs', 'Space'].map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            selectedCategory = value;
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location
                      const Text(
                        'LOCATION',
                        style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: locationController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Bio-Medical Lab A',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF8083FF), width: 1.5),
                          ),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter location' : null,
                      ),
                      const SizedBox(height: 16),

                      // Max Reservation Days
                      const Text(
                        'MAX RESERVATION DAYS',
                        style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: maxDaysController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. 3',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF8083FF), width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Enter max days';
                          if (int.tryParse(value) == null) return 'Must be a number';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (dialogFormKey.currentState?.validate() ?? false) {
                      // Get JWT token from AuthBloc
                      final authState = context.read<AuthBloc>().state;
                      if (authState is! AuthAuthenticated) {
                        Navigator.pop(dialogContext);
                        return;
                      }
                      final token = authState.token;

                      // Dispatch to BLoC → NestJS → Cloudinary + Neon DB
                      context.read<MarketplaceBloc>().add(
                        CreateAssetEvent(
                          name: titleController.text.trim(),
                          category: selectedCategory,
                          imagePath: pickedImagePath,
                          token: token,
                          maxReservationDays: int.tryParse(maxDaysController.text.trim()) ?? 3,
                        ),
                      );

                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Asset is being saved to Neon DB...'),
                          backgroundColor: Color(0xFF8083FF),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8083FF),
                    foregroundColor: const Color(0xFF0D0096),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Create Asset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showModifyAssetDialog(BuildContext context, MarketplaceAsset asset) {
    final titleController = TextEditingController(text: asset.title);
    final maxDaysController = TextEditingController(text: asset.maxReservationDays.toString());
    String selectedCategory = asset.category;
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Modify Asset',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B1326),
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Asset Name
                  const Text('ASSET NAME', style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8083FF), width: 1.5)),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter asset name' : null,
                  ),
                  const SizedBox(height: 16),
                  // Category
                  const Text('CATEGORY', style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: ['Hardware', 'Labs', 'Space'].map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                    onChanged: (value) { if (value != null) selectedCategory = value; },
                    decoration: InputDecoration(
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Max Reservation Days
                  const Text('MAX RESERVATION DAYS', style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: maxDaysController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8083FF), width: 1.5)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Enter max days';
                      if (int.tryParse(value) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                if (dialogFormKey.currentState?.validate() ?? false) {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is! AuthAuthenticated) {
                    Navigator.pop(dialogContext);
                    return;
                  }
                  context.read<MarketplaceBloc>().add(
                    UpdateAssetEvent(
                      id: asset.id,
                      name: titleController.text.trim(),
                      category: selectedCategory,
                      token: authState.token,
                      maxReservationDays: int.tryParse(maxDaysController.text.trim()) ?? 3,
                    ),
                  );
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updating Asset...'), backgroundColor: Color(0xFF8083FF)));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8083FF),
                foregroundColor: const Color(0xFF0D0096),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Modify Asset'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, MarketplaceAsset asset) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Asset?', style: TextStyle(fontFamily: 'Newsreader', fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0B1326))),
          content: Text('Are you sure you want to delete ${asset.title}? This cannot be undone.', style: const TextStyle(fontFamily: 'Geist', fontSize: 14, color: Color(0xFF64748B))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                final authState = context.read<AuthBloc>().state;
                if (authState is AuthAuthenticated) {
                  context.read<MarketplaceBloc>().add(DeleteAssetEvent(id: asset.id, token: authState.token));
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleting Asset...'), backgroundColor: Colors.redAccent));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Strict Visual Rule: Pure White background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1326),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC0C1FF)),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'INVENTORY CONTROLS',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFDAE2FD),
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFC0C1FF)),
            onPressed: () => _showAddAssetDialog(context),
          ),
        ],
        elevation: 0,
      ),
      body: BlocBuilder<MarketplaceBloc, MarketplaceState>(
        builder: (context, state) {
          // ── Loading ──────────────────────────────────────────────────────
          if (state is MarketplaceLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8083FF)),
            );
          }

          // ── Error ────────────────────────────────────────────────────────
          if (state is MarketplaceError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
                  const SizedBox(height: 12),
                  Text(state.message, style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<MarketplaceBloc>().add(FetchMarketplaceAssetsEvent()),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8083FF)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // ── Loaded: real list from Neon DB ───────────────────────────────
          final assets = state is MarketplaceLoaded ? state.assets : <MarketplaceAsset>[];

          return RefreshIndicator(
            color: const Color(0xFF8083FF),
            backgroundColor: const Color(0xFF0B1326),
            strokeWidth: 2.5,
            onRefresh: () async {
              context.read<MarketplaceBloc>().add(FetchMarketplaceAssetsEvent());
              await context.read<MarketplaceBloc>().stream.firstWhere(
                (s) => s is MarketplaceLoaded || s is MarketplaceError,
              );
            },
            child: assets.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No assets yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: assets.length,
                    itemBuilder: (context, index) {
                      final asset = assets[index];
                      final isAvailable = asset.status == 'LIVE';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Header row: ID + status badge ───────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  asset.id.substring(0, 8).toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Geist',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                                        : const Color(0xFF64748B).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isAvailable ? 'Active' : 'Reserved',
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isAvailable
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // ── Thumbnail + title ─────────────────────────────
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (asset.imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      asset.imageUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 56,
                                        height: 56,
                                        color: const Color(0xFFF1F5F9),
                                        child: const Icon(Icons.devices, color: Color(0xFF8083FF)),
                                      ),
                                    ),
                                  ),
                                if (asset.imageUrl.isNotEmpty) const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asset.title,
                                        style: const TextStyle(
                                          fontFamily: 'Geist',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        asset.category,
                                        style: const TextStyle(
                                          fontFamily: 'Geist',
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // ── Action Buttons ────────────────────────────────
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: isAvailable ? () => _showModifyAssetDialog(context, asset) : null,
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: const Text('Modify', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8083FF),
                                    foregroundColor: const Color(0xFF0D0096),
                                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                                    disabledForegroundColor: const Color(0xFF94A3B8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: isAvailable ? () => _confirmDelete(context, asset) : null,
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.redAccent,
                                  disabledColor: const Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
