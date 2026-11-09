# Chronos — Backend & AI Microservices (NestJS & Python RAG)

[![NestJS](https://img.shields.io/badge/NestJS-10.x-E0234E?logo=nestjs&logoColor=white)](https://nestjs.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas%20%7C%20Local-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com)
[![Prisma](https://img.shields.io/badge/Prisma-ORM-2D3748?logo=prisma&logoColor=white)](https://www.prisma.io)
[![LangChain](https://img.shields.io/badge/LangChain-Python-1C3C3C?logo=langchain&logoColor=white)](https://www.langchain.com)
[![Pinecone](https://img.shields.io/badge/Pinecone-Vector%20DB-000000?logoColor=white)](https://www.pinecone.io)
[![JWT](https://img.shields.io/badge/Auth-JWT%20%26%20RBAC-blue)](https://jwt.io)

Core backend API and AI Gateway for the **Chronos Smart Campus Equipment Sharing Platform**, engineered during an **AIESEC Global Talent Internship** at **Maharishi Markandeshwar University (MMDU)**.

---

## 🏗️ Architecture Overview

The backend is built around a modular **NestJS** microservice architecture integrated with a **Multimodal RAG (Retrieval-Augmented Generation)** service:

```
src/
├── auth/                # JWT authentication, Argon2 hashing, RBAC guards
├── users/               # Student profile, wallet management, role assignment
├── assets/              # Equipment inventory, categorization, availability status
├── bookings/            # Reservation engine, date conflict checks, QR key generation
├── module2/             # Visual inspection & damage detection API gateway
└── module3/
    └── chat/            # Multimodal RAG Chatbot gateway (LangChain + Pinecone)
prisma/
└── schema.prisma        # Prisma models for MongoDB (User, Asset, Reservation, Ticket)
```

---

## 🤖 Multimodal RAG & AI Troubleshooting Engine

1. **Vector Ingestion (LangChain + Pinecone):** MMDU lab equipment manuals (PDFs) are chunked, embedded, and stored in a Pinecone vector index.
2. **Flexible Multimodal Queries:** Accepts text-only, error image-only, or combined text + image inputs.
3. **Autonomous Web Search Fallback:** If manuals lack the troubleshooting steps, the agent autonomously queries the web, formulates verified repair instructions, and dynamically indexes the new knowledge back into Pinecone for continuous learning.
4. **Cloudinary Media Pipeline:** Secure external hosting for error photos, equipment return scans, and user media.

---

## 🚀 Getting Started

### Prerequisites
- [Node.js](https://nodejs.org) (v18+ or v20+)
- [MongoDB](https://www.mongodb.com) instance (local or Atlas)
- [Python 3.10+](https://www.python.org) (for AI microservices)

### 1. Installation
Clone the repository and switch to the `backend` branch:
```bash
git clone -b backend https://github.com/negzaoui16/Project-Chronos.git
cd Project-Chronos
npm install
```

### 2. Environment Configuration
Copy `.env.example` to `.env` and fill in your local or staging credentials:
```bash
cp .env.example .env
```

Key environment variables:
- `DATABASE_URL`: MongoDB connection string
- `JWT_SECRET`: Secret key for token signing
- `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`
- `PINECONE_API_KEY`, `PINECONE_INDEX`
- `HUGGINGFACE_TOKEN`

### 3. Database Synchronization
```bash
npx prisma generate
```

### 4. Run Server
```bash
# Development mode with hot-reload
npm run start:dev

# Production build
npm run build
npm run start:prod
```
The server will start on `http://localhost:3000`.
