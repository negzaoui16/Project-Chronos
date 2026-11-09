#!/bin/bash

# Root directory name
ROOT_DIR="Backend"

echo "Initializing directory structure for: $ROOT_DIR"

# Create directories
mkdir -p "$ROOT_DIR/prisma"
mkdir -p "$ROOT_DIR/src/common/guards"
mkdir -p "$ROOT_DIR/src/common/filters"
mkdir -p "$ROOT_DIR/src/prisma"
mkdir -p "$ROOT_DIR/src/module1/chronos-backend"
mkdir -p "$ROOT_DIR/src/module2/module2-api"
mkdir -p "$ROOT_DIR/src/module3/auth"
mkdir -p "$ROOT_DIR/src/module3/gateway-rag"
mkdir -p "$ROOT_DIR/src/assets"
mkdir -p "$ROOT_DIR/src/bookings"

# Touch configuration files
touch "$ROOT_DIR/.env"
touch "$ROOT_DIR/.gitignore"
touch "$ROOT_DIR/package.json"
touch "$ROOT_DIR/tsconfig.json"
touch "$ROOT_DIR/prisma/schema.prisma"

# Touch source skeleton files
touch "$ROOT_DIR/src/main.ts"
touch "$ROOT_DIR/src/app.module.ts"
touch "$ROOT_DIR/src/common/guards/jwt-auth.guard.ts"
touch "$ROOT_DIR/src/common/guards/roles.guard.ts"
touch "$ROOT_DIR/src/common/filters/http-exception.filter.ts"
touch "$ROOT_DIR/src/prisma/prisma.module.ts"
touch "$ROOT_DIR/src/prisma/prisma.service.ts"

# Module 1
touch "$ROOT_DIR/src/module1/chronos-backend/chronos-backend.module.ts"
touch "$ROOT_DIR/src/module1/chronos-backend/chronos-backend.controller.ts"
touch "$ROOT_DIR/src/module1/chronos-backend/chronos-backend.service.ts"

# Module 2
touch "$ROOT_DIR/src/module2/module2-api/module2-api.module.ts"
touch "$ROOT_DIR/src/module2/module2-api/module2-api.service.ts"

# Module 3 (Auth, Gateway RAG)
touch "$ROOT_DIR/src/module3/auth/auth.module.ts"
touch "$ROOT_DIR/src/module3/auth/auth.controller.ts"
touch "$ROOT_DIR/src/module3/auth/auth.service.ts"

touch "$ROOT_DIR/src/module3/gateway-rag/gateway-rag.module.ts"
touch "$ROOT_DIR/src/module3/gateway-rag/gateway-rag.controller.ts"
touch "$ROOT_DIR/src/module3/gateway-rag/gateway-rag.service.ts"

# Shared integration modules (Assets, Bookings)
touch "$ROOT_DIR/src/assets/assets.module.ts"
touch "$ROOT_DIR/src/assets/assets.controller.ts"
touch "$ROOT_DIR/src/assets/assets.service.ts"

touch "$ROOT_DIR/src/bookings/bookings.module.ts"
touch "$ROOT_DIR/src/bookings/bookings.controller.ts"
touch "$ROOT_DIR/src/bookings/bookings.service.ts"

echo "Directory structure and skeleton files created successfully in /$ROOT_DIR"
