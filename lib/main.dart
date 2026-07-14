import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_bloc.dart';
import 'package:frontend/module3/bookings/bloc/bookings_bloc.dart';
import 'package:frontend/module3/chat/bloc/chat_bloc.dart';

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
          create: (context) => AuthBloc(),
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
        home: const PlaceholderHomeScreen(),
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
