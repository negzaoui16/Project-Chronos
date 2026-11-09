import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_event.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_bloc.dart';
import 'package:frontend/module3/bookings/bloc/bookings_bloc.dart';
import 'package:frontend/module3/chat/bloc/chat_bloc.dart';

import 'package:frontend/module1/wallet/wallet_balance_screen.dart';
import 'package:frontend/module1/wallet/escrow_deposit_screen.dart';
import 'package:frontend/module1/wallet/reputation_score_screen.dart';
import 'package:frontend/module1/wallet/governance_vote_screen.dart';
import 'package:frontend/module2/inspection/admin_inspection_dashboard.dart';
import 'package:frontend/module2/inspection/change_detection_view.dart';
import 'package:frontend/module2/inspection/damage_severity_report.dart';
import 'package:frontend/module3/auth/presentation/login_screen.dart';
import 'package:frontend/module3/auth/presentation/register_screen.dart';
import 'package:frontend/module3/auth/presentation/forgot_password_screen.dart';
import 'package:frontend/module3/auth/presentation/student_profile_screen.dart';
import 'package:frontend/module3/marketplace/presentation/marketplace_home_screen.dart';
import 'package:frontend/module3/marketplace/presentation/search_filter_screen.dart';
import 'package:frontend/module3/marketplace/presentation/admin_asset_management_screen.dart';
import 'package:frontend/module3/bookings/presentation/calendar_booking_screen.dart';
import 'package:frontend/module3/bookings/presentation/my_bookings_screen.dart';
import 'package:frontend/module3/bookings/presentation/dynamic_qr_key_screen.dart';
import 'package:frontend/module3/chat/presentation/rag_troubleshoot_chat_screen.dart';
import 'package:frontend/module3/chat/presentation/chat_history_screen.dart';
import 'package:frontend/module3/core/presentation/notification_hub_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc()..add(CheckAuthRequested()),
        ),
        BlocProvider<MarketplaceBloc>(
          create: (context) => MarketplaceBloc(),
        ),
        BlocProvider<BookingsBloc>(
          create: (context) => BookingsBloc(),
        ),
        BlocProvider<ChatBloc>(
          create: (context) => ChatBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Chronos Monolithic-Modular Client',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF8083FF)),
                ),
              );
            }
            if (state is AuthAuthenticated) {
              return const MarketplaceHomeScreen();
            }
            return const LoginScreen();
          },
        ),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/marketplace': (context) => const MarketplaceHomeScreen(),
          '/search-filter': (context) => const SearchFilterScreen(),
          '/admin-asset-management': (context) => const AdminAssetManagementScreen(),
          '/calendar-booking': (context) => const CalendarBookingScreen(),
          '/my-bookings': (context) => const MyBookingsScreen(),
          '/dynamic-qr-key': (context) => const DynamicQrKeyScreen(),
          '/rag-troubleshoot-chat': (context) => const RagTroubleshootChatScreen(),
          '/chat-history': (context) => const ChatHistoryScreen(),
          '/student-profile': (context) => const StudentProfileScreen(),
          '/notification-hub': (context) => const NotificationHubScreen(),
          '/wallet-balance': (context) => const WalletBalanceScreen(),
          '/escrow-deposit': (context) => const EscrowDepositScreen(),
          '/reputation-score': (context) => const ReputationScoreScreen(),
          '/governance-vote': (context) => const GovernanceVoteScreen(),
          '/admin-inspection-dashboard': (context) => const AdminInspectionDashboard(),
          '/change-detection': (context) => const ChangeDetectionView(),
          '/damage-severity-report': (context) => const DamageSeverityReport(bookingId: '', reportData: {}),
        },
      ),
    );
  }
}

class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chronos Mobile Gateway'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.dashboard_customize_rounded,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),
              const Text(
                'Chronos Platform Decoupled Client UI',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Module 3 Features (Auth, Booking, RAG Chat, Marketplace) Active',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
