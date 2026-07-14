#!/bin/bash

# Root directory name
FRONTEND_DIR="lib"

echo "Initializing Flutter directory structure inside: $FRONTEND_DIR"

# Create directories
mkdir -p "$FRONTEND_DIR/core/theme"
mkdir -p "$FRONTEND_DIR/core/network"
mkdir -p "$FRONTEND_DIR/core/constants"
mkdir -p "$FRONTEND_DIR/module1/wallet"
mkdir -p "$FRONTEND_DIR/module2/inspection"

mkdir -p "$FRONTEND_DIR/module3/auth/bloc"
mkdir -p "$FRONTEND_DIR/module3/auth/presentation"

mkdir -p "$FRONTEND_DIR/module3/marketplace/bloc"
mkdir -p "$FRONTEND_DIR/module3/marketplace/presentation"

mkdir -p "$FRONTEND_DIR/module3/bookings/bloc"
mkdir -p "$FRONTEND_DIR/module3/bookings/presentation"

mkdir -p "$FRONTEND_DIR/module3/chat/bloc"
mkdir -p "$FRONTEND_DIR/module3/chat/presentation"

# Module 3 Auth Bloc
touch "$FRONTEND_DIR/module3/auth/bloc/auth_bloc.dart"
touch "$FRONTEND_DIR/module3/auth/bloc/auth_event.dart"
touch "$FRONTEND_DIR/module3/auth/bloc/auth_state.dart"

# Module 3 Auth Presentation
touch "$FRONTEND_DIR/module3/auth/presentation/login_screen.dart"
touch "$FRONTEND_DIR/module3/auth/presentation/register_screen.dart"
touch "$FRONTEND_DIR/module3/auth/presentation/forgot_password_screen.dart"

# Module 3 Marketplace Bloc
touch "$FRONTEND_DIR/module3/marketplace/bloc/marketplace_bloc.dart"
touch "$FRONTEND_DIR/module3/marketplace/bloc/marketplace_event.dart"
touch "$FRONTEND_DIR/module3/marketplace/bloc/marketplace_state.dart"

# Module 3 Marketplace Presentation
touch "$FRONTEND_DIR/module3/marketplace/presentation/marketplace_home_screen.dart"
touch "$FRONTEND_DIR/module3/marketplace/presentation/asset_details_screen.dart"
touch "$FRONTEND_DIR/module3/marketplace/presentation/search_screen.dart"
touch "$FRONTEND_DIR/module3/marketplace/presentation/admin_asset_screen.dart"

# Module 3 Bookings Bloc
touch "$FRONTEND_DIR/module3/bookings/bloc/bookings_bloc.dart"
touch "$FRONTEND_DIR/module3/bookings/bloc/bookings_event.dart"
touch "$FRONTEND_DIR/module3/bookings/bloc/bookings_state.dart"

# Module 3 Bookings Presentation
touch "$FRONTEND_DIR/module3/bookings/presentation/calendar_booking_screen.dart"
touch "$FRONTEND_DIR/module3/bookings/presentation/my_bookings_screen.dart"
touch "$FRONTEND_DIR/module3/bookings/presentation/qr_key_screen.dart"
touch "$FRONTEND_DIR/module3/bookings/presentation/asset_return_screen.dart"
touch "$FRONTEND_DIR/module3/bookings/presentation/booking_confirmation_screen.dart"

# Module 3 Chat Bloc
touch "$FRONTEND_DIR/module3/chat/bloc/chat_bloc.dart"
touch "$FRONTEND_DIR/module3/chat/bloc/chat_event.dart"
touch "$FRONTEND_DIR/module3/chat/bloc/chat_state.dart"

# Module 3 Chat Presentation
touch "$FRONTEND_DIR/module3/chat/presentation/rag_troubleshoot_chat_screen.dart"
touch "$FRONTEND_DIR/module3/chat/presentation/chat_history_screen.dart"

echo "Directory structure and empty skeleton files initialized successfully in $FRONTEND_DIR"
