import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_bloc.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_event.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_state.dart';
import 'package:frontend/module3/marketplace/presentation/search_filter_screen.dart';
import 'package:frontend/module3/marketplace/presentation/asset_details_screen.dart';
import 'package:frontend/module3/marketplace/presentation/admin_asset_management_screen.dart';
import 'package:frontend/module3/bookings/presentation/my_bookings_screen.dart';
import 'package:frontend/module3/chat/presentation/rag_troubleshoot_chat_screen.dart';
import 'package:frontend/module3/auth/presentation/student_profile_screen.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['All Resources', 'Hardware', 'Labs', 'Space'];

  @override
  void initState() {
    super.initState();
    context.read<MarketplaceBloc>().add(FetchMarketplaceAssetsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white, // Strict Visual Rule: 100% Pure White background
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xCC0B1326), // bg-hero-overlay (rgba(11, 19, 38, 0.8))
            border: Border(
              bottom: BorderSide(
                color: Color(0x1A464554), // border-b border-outline-variant/10
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Color(0xFFC0C1FF)), // primary
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CHRONOS',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDAE2FD), // text-on-surface
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, authState) {
                          final isAdmin = authState is AuthAuthenticated && authState.user['role'] == 'ADMIN';
                          if (isAdmin) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFFC0C1FF), size: 26),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AdminAssetManagementScreen()),
                                  );
                                },
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const StudentProfileScreen()),
                          );
                        },
                        child: BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, authState) {
                            String profileImageUrl = 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';
                            if (authState is AuthAuthenticated) {
                              profileImageUrl = authState.user['profileImageUrl'] ?? profileImageUrl;
                            }
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x33C0C1FF), // ring-primary/20
                                  width: 2,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(profileImageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF8083FF),
        backgroundColor: const Color(0xFF0B1326),
        strokeWidth: 2.5,
        onRefresh: () async {
          context.read<MarketplaceBloc>().add(FetchMarketplaceAssetsEvent());
          // Wait for the BLoC to respond
          await context.read<MarketplaceBloc>().stream.firstWhere(
            (state) => state is MarketplaceLoaded || state is MarketplaceError,
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Hero Section (height ~45vh)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: size.height * 0.45 > 350 ? size.height * 0.45 : 350,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuDfCGxAlJd6uGKBvU14OoWv-iGagt-MOAFRDQHuuiSnnanSS77yasP-XlChNaVFi5_WUIJZECVvYAcc6--de9p0Nk4r6sBBgH5RaKRiALCb3UbJyOb5gIC-1nNBWMzOxJJ0gw88wVnxPPw89Nk7MV-WOhR-hpMxf6TdA8RQKBbigQwUpFPsBxFLnRGfac5KBywA0ERrAk_ZqOu_07dR4L3uzSPwC6IKcdEoUfwJuoBqkVmqDNegxEEm',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Dark overlay gradient matching Tailwind colors
                Container(
                  height: size.height * 0.45 > 350 ? size.height * 0.45 : 350,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0B1326).withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
                // Hero Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'RESOURCE MARKETPLACE',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC0C1FF), // primary
                          letterSpacing: 3.6, // tracking-[0.3em]
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Discover Technical Excellence',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDAE2FD), // text-on-surface
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Main Content Area (Overlapping sheet, pure white canvas background)
            Transform.translate(
              offset: const Offset(0, -40),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white, // Pure white canvas
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search & Filter controls
                      Row(
                        children: [
                          Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SearchFilterScreen()),
                                  );
                                },
                                child: const AbsorbPointer(
                                  child: TextField(
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 15,
                                      color: Color(0xFF0B1326),
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Color(0xFF64748B), // text-muted
                                        size: 20,
                                      ),
                                      hintText: 'Search instruments, labs, or software...',
                                      hintStyle: TextStyle(color: Color(0x8064748B)),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Horizontal category filters chips
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final isActive = _selectedCategoryIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryIndex = index;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFFC0C1FF) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isActive ? const Color(0xFFC0C1FF) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    _categories[index],
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isActive ? const Color(0xFF0D0096) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 36),

                      // BLoC State Management Integration for Asset Grid
                      BlocBuilder<MarketplaceBloc, MarketplaceState>(
                        builder: (context, state) {
                          if (state is MarketplaceLoading) {
                            return const SizedBox(
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF8083FF),
                                ),
                              ),
                            );
                          } else if (state is MarketplaceLoaded) {
                            final selectedCategory = _categories[_selectedCategoryIndex];
                            final filteredAssets = _selectedCategoryIndex == 0
                                ? state.assets
                                : state.assets.where((asset) => asset.category.toLowerCase() == selectedCategory.toLowerCase()).toList();

                            if (filteredAssets.isEmpty) {
                              return const SizedBox(
                                height: 200,
                                child: Center(
                                  child: Text(
                                    'No resources found in this category.',
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: size.width > 900 ? 3 : (size.width > 600 ? 2 : 1),
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: filteredAssets.length,
                              itemBuilder: (context, index) {
                                final asset = filteredAssets[index];
                                final isLive = asset.status == 'LIVE';

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AssetDetailsScreen(asset: asset),
                                      ),
                                    );
                                  },
                                  child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Image Header
                                      Expanded(
                                        flex: 5,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                              child: Image.network(
                                                asset.imageUrl,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            // Availability Badge
                                            Positioned(
                                              top: 12,
                                              left: 12,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isLive ? const Color(0xFF22C55E) : const Color(0xFF1E293B),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (isLive) ...[
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: const BoxDecoration(
                                                          color: Colors.white,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    Text(
                                                      asset.status,
                                                      style: const TextStyle(
                                                        fontFamily: 'Geist',
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Body Card
                                      Expanded(
                                        flex: 5,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      asset.title,
                                                      style: const TextStyle(
                                                        fontFamily: 'Geist',
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.bookmark_outline,
                                                    color: Color(0xFF94A3B8),
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Expanded(
                                                child: Text(
                                                  asset.description,
                                                  style: const TextStyle(
                                                    fontFamily: 'Geist',
                                                    fontSize: 13,
                                                    color: Color(0xFF64748B), // text-muted
                                                  ),
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              const Divider(color: Color(0xFFF8FAFC), height: 1),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        isLive ? Icons.schedule : Icons.lock_clock,
                                                        color: isLive ? const Color(0xFF8083FF) : const Color(0xFF94A3B8),
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        asset.availabilityText,
                                                        style: const TextStyle(
                                                          fontFamily: 'Geist',
                                                          fontSize: 11,
                                                          color: Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    color: Color(0xFF8083FF),
                                                    size: 16,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ),
                                );
                              },
                            );
                            } else if (state is MarketplaceError) {
                              return SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'Error loading assets: ${state.message}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 48),

                      // Secondary CTA Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC), // Slate-50
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Can't find what you need?",
                              style: TextStyle(
                                fontFamily: 'Newsreader',
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Submit a resource request to the departmental procurement board or browse partnered institutional inventories.',
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AdminAssetManagementScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8083FF), // primary-container
                                foregroundColor: const Color(0xFF0D0096), // on-primary-container
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Request Resource',
                                style: TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
      // Floating Bottom Navigation Bar (Model 4 DNA style)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          border: const Border(
            top: BorderSide(
              color: Color(0xFFE2E8F0), // border-subtle
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Active item: Resources
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8083FF).withValues(alpha: 0.2), // primary-container/20
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.storefront,
                        color: Color(0xFF0D0096), // on-primary-container
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Resources',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D0096),
                        ),
                      ),
                    ],
                  ),
                ),
                // Activity
                 IconButton(
                  icon: const Icon(Icons.history, color: Color(0xFF64748B)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
                    );
                  },
                ),
                // Connect
                IconButton(
                  icon: const Icon(Icons.smart_toy_outlined, color: Color(0xFF64748B)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RagTroubleshootChatScreen()),
                    );
                  },
                ),
                // Account
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF64748B)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StudentProfileScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
