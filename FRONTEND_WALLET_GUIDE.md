# Chronos Wallet Page — Frontend Integration Guide

This guide explains how the frontend should authenticate a student and consume
the Chronos wallet API.

## Backend URL

Local development:

```text
http://localhost:3000
```

The backend can be started with:

```bash
cd D:\Backend
npm run start:dev
```

For production, configure the frontend with an environment variable:

```env
VITE_API_URL=https://your-backend-domain.com
```

## 1. Student login

### Request

```http
POST /auth/login
Content-Type: application/json
```

```json
{
  "email": "student@example.com",
  "password": "password"
}
```

### Response

```json
{
  "token": "JWT_TOKEN",
  "user": {
    "walletAddress": "0x...",
    "chronosBalance": "100.0",
    "tokenMintStatus": "CONFIRMED"
  }
}
```

The JWT token must be sent in the `Authorization` header when requesting the
wallet page.

## 2. Get the authenticated student's wallet

### Request

```http
GET /wallet/me
Authorization: Bearer <JWT_TOKEN>
```

This endpoint identifies the student from the JWT. The frontend must not send a
user ID or wallet address.

### Response

```json
{
  "walletAddress": "0xD1b1D9803a318a4B16693c0e1392F0518741ee58",
  "chronosBalance": "100.0",
  "tokenName": "Chronos Token",
  "tokenSymbol": "CHRONOS",
  "tokenMintStatus": "CONFIRMED",
  "tokenMintTransactionHash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "tokenMintBlockNumber": 42473059,
  "tokenMintedAt": "2026-07-17T12:31:00.644Z",
  "walletExplorerUrl": "https://amoy.polygonscan.com/address/0xD1b1D9803a318a4B16693c0e1392F0518741ee58",
  "transactionExplorerUrl": "https://amoy.polygonscan.com/tx/0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "contractAddress": "0x38020446c7350f524000F8f8074FF27E26b78d8D"
}
```

`chronosBalance` is read live from Polygon Amoy.

## 3. Get on-chain wallet / escrow transaction history

History is loaded live from Polygon Amoy (not a database ledger):

- Alchemy `alchemy_getAssetTransfers` for CHRONOS transfer hashes
- `ReservationEscrow.getReservation` for lock / release / slash classification

Not included: ERC-20 `approve` and native POL gas top-ups (no indexed transfer).

### Request

```http
GET /wallet/me/transactions?limit=50
Authorization: Bearer <JWT_TOKEN>
```

### Response

```json
{
  "walletAddress": "0x6011c845D36272bCD4cd3dfeb6B8BA2Ff875c870",
  "escrowAddress": "0x0Ec506683781c37900982CC37e0B93f4D2Faf3e0",
  "tokenAddress": "0x38020446c7350f524000F8f8074FF27E26b78d8D",
  "items": [
    {
      "type": "ESCROW_RELEASE",
      "transactionHash": "0x...",
      "blockNumber": 43417679,
      "logIndex": null,
      "timestamp": 1720000000,
      "amount": "20.0",
      "amountAsset": "CHRONOS",
      "reservationId": "2",
      "penalty": null,
      "refund": null,
      "explorerUrl": "https://amoy.polygonscan.com/tx/0x..."
    },
    {
      "type": "ESCROW_LOCK",
      "transactionHash": "0x...",
      "blockNumber": 43417675,
      "logIndex": null,
      "timestamp": 1720000000,
      "amount": "20.0",
      "amountAsset": "CHRONOS",
      "reservationId": "2",
      "penalty": null,
      "refund": null,
      "explorerUrl": "https://amoy.polygonscan.com/tx/0x..."
    },
    {
      "type": "TOKEN_MINT",
      "transactionHash": "0x...",
      "blockNumber": 42473059,
      "logIndex": null,
      "timestamp": 1720000000,
      "amount": "100.0",
      "amountAsset": "CHRONOS",
      "reservationId": null,
      "penalty": null,
      "refund": null,
      "explorerUrl": "https://amoy.polygonscan.com/tx/0x..."
    }
  ]
}
```

`type` values: `TOKEN_MINT`, `ESCROW_LOCK`, `ESCROW_RELEASE`, `ESCROW_SLASH`.

## 4. TypeScript types

```ts
export type TokenMintStatus =
  | "NOT_REQUIRED"
  | "PENDING"
  | "SUBMITTED"
  | "CONFIRMED"
  | "FAILED";

export interface WalletOverview {
  walletAddress: string;
  chronosBalance: string;
  tokenName: string;
  tokenSymbol: string;
  tokenMintStatus: TokenMintStatus;
  tokenMintTransactionHash: string | null;
  tokenMintBlockNumber: number | null;
  tokenMintedAt: string | null;
  walletExplorerUrl: string;
  transactionExplorerUrl: string | null;
  contractAddress: string;
}
```

Keep `chronosBalance` as a string. Converting blockchain token values to a
JavaScript number can cause precision loss.

## 5. API client

```ts
const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:3000";

export async function getMyWallet(
  token: string,
): Promise<WalletOverview> {
  const response = await fetch(`${API_URL}/wallet/me`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message ?? "Unable to load wallet");
  }

  return response.json();
}

export async function getMyWalletTransactions(
  token: string,
  limit = 50,
): Promise<{
  walletAddress: string;
  items: Array<{
    type: string;
    transactionHash: string;
    blockNumber: number;
    timestamp: number | null;
    amount: string | null;
    amountAsset: "CHRONOS";
    reservationId: string | null;
    explorerUrl: string;
  }>;
}> {
  const response = await fetch(
    `${API_URL}/wallet/me/transactions?limit=${limit}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
    },
  );

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message ?? "Unable to load wallet history");
  }

  return response.json();
}
```

## 6. React wallet page example

```tsx
import { useEffect, useState } from "react";
import { getMyWallet, WalletOverview } from "./wallet-api";

export function WalletPage() {
  const [wallet, setWallet] = useState<WalletOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const token = localStorage.getItem("token");

    if (!token) {
      setError("Authentication required");
      setLoading(false);
      return;
    }

    getMyWallet(token)
      .then(setWallet)
      .catch((error: Error) => setError(error.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>Loading wallet...</p>;
  if (error) return <p>{error}</p>;
  if (!wallet) return <p>Wallet unavailable</p>;

  return (
    <section>
      <h1>{wallet.tokenName}</h1>

      <strong>
        {wallet.chronosBalance} {wallet.tokenSymbol}
      </strong>

      <p>Wallet: {wallet.walletAddress}</p>
      <p>Allocation status: {wallet.tokenMintStatus}</p>

      <a
        href={wallet.walletExplorerUrl}
        target="_blank"
        rel="noreferrer"
      >
        View wallet on Polygonscan
      </a>

      {wallet.transactionExplorerUrl && (
        <a
          href={wallet.transactionExplorerUrl}
          target="_blank"
          rel="noreferrer"
        >
          View mint transaction
        </a>
      )}
    </section>
  );
}
```

## 6. Status handling

| Status | Frontend behavior |
|---|---|
| `CONFIRMED` | Display the CHRONOS balance normally |
| `PENDING` | Display “Preparing token allocation” |
| `SUBMITTED` | Display “Waiting for Polygon confirmation” |
| `FAILED` | Display “Token allocation failed; contact support” |
| `NOT_REQUIRED` | No student token allocation is expected |

For `PENDING` or `SUBMITTED`, the frontend may refresh `/wallet/me` every
10–15 seconds. Stop polling after `CONFIRMED` or `FAILED`.

## 7. HTTP errors

| Status | Meaning | Frontend behavior |
|---|---|---|
| `401` | JWT is missing, invalid, or expired | Redirect to login |
| `404` | User or wallet was not found | Show wallet unavailable |
| `503` | Polygon RPC is temporarily unavailable | Offer a retry button |

## 8. Security rules

- Students do not use MetaMask.
- The frontend must never request or display a private key.
- The frontend does not need Ethers.js.
- Never send a user ID or wallet address to `/wallet/me`.
- Always use the JWT in `Authorization: Bearer <token>`.
- Display balances from the backend instead of querying Polygon directly.
- Do not expose `ADMIN_PRIVATE_KEY`, `ENCRYPTION_KEY`, or backend `.env` values.

## Verified live example

The integration was tested on Polygon Amoy:

- Wallet: `0xD1b1D9803a318a4B16693c0e1392F0518741ee58`
- Balance: `100.0 CHRONOS`
- Mint status: `CONFIRMED`
- Contract: `0x38020446c7350f524000F8f8074FF27E26b78d8D`
- Mint transaction:
  `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`

