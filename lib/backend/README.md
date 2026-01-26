# Luyumi Backend

Backend server for Luyumi Launcher built with [Bun](https://bun.sh) and [ElysiaJS](https://elysiajs.com).

## Prerequisites

- [Bun](https://bun.sh) installed.

## Installation

```bash
bun install
```

## Running

To start the development server:

```bash
bun run dev
```

The server will start at `http://localhost:3000`.

## API Endpoints

### Authentication
- **URL:** `/game-session/child`
- **Method:** `POST`
- **Body:** `{ "name": "PlayerName", "uuid": "...", "scopes": [...] }`
- **Response:** `{ "IdentityToken": "...", "SessionToken": "..." }`

### Version Check
- **URL:** `/api/version_client`
- **Method:** `GET`
- **Response:** `{ "client_version": "0.1.0-release" }`
