---
name: Cross-platform Mobile - Rider App
description: Hướng dẫn phát triển Rider App bằng Flutter/React Native với WebSocket, maps, và payment.
---

# Cross-platform Mobile - Rider App

## Khi nào dùng skill này?
- Phát triển Rider App (Flutter hoặc React Native)
- Implement live tracking, booking flow, chat
- Integrate maps SDK và payment

## Tech Options
| Framework | Pros | Cons |
|-----------|------|------|
| **Flutter** | Dart, hot reload, beautiful UI | Smaller ecosystem |
| **React Native** | JS/TS ecosystem, large community | Bridge overhead |

## Key Features
1. **Home**: Map + search destination + book ride
2. **Live Tracking**: Watch driver move on map realtime
3. **Chat**: In-app messaging with driver
4. **Payment**: Cash, Wallet, MoMo, ZaloPay
5. **Trip History**: Past rides, ratings, receipts

## WebSocket Integration
```dart
// Flutter Socket.io
final socket = IO.io('wss://api.xebuonho.vn/rides', 
  IO.OptionBuilder()
    .setTransports(['websocket'])
    .setAuth({'token': jwt})
    .build());

socket.on('driver:location', (data) => updateDriverMarker(data));
socket.on('ride:status', (data) => updateRideStatus(data));
```

## State Management
- **Flutter**: BLoC, Riverpod, or Provider
- **React Native**: Redux Toolkit or Zustand

## References
- Architecture: [docs/architecture/MOBILE-APPS.md](../../docs/architecture/MOBILE-APPS.md)
