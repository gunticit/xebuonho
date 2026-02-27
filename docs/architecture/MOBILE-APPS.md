# 📱 Mobile Apps Architecture

> Driver App: **Native** (Kotlin/Swift) | Rider App: **Cross-platform** (Flutter/React Native)

## Tại sao phải tách chiến lược?

| Yêu cầu | Driver App | Rider App |
|----------|-----------|-----------|
| Background location | ✅ 8-10 tiếng/ngày | ❌ Không cần |
| Battery optimization | Cực kỳ quan trọng | Bình thường |
| OS-level integration | Sâu (Foreground Service) | Nhẹ |
| Số lượng platform | 2 app riêng ok | Cần nhanh, 1 codebase |
| Mạng yếu | Phải hoạt động | Thường ổn định |

---

## 1. Driver App - Native (Kotlin/Swift)

### Tại sao phải Native?

**Bài toán lớn nhất**: Điện thoại (đặc biệt Android TQ) tự **kill app khi tắt màn hình** để tiết kiệm pin → Tài xế "đứng im" trên bản đồ → Mất cuốc.

### Kiến trúc Driver App

```
┌──────────────────────────────────────────┐
│              Driver App                   │
├──────────────────────────────────────────┤
│  UI Layer (Activities/Fragments)          │
│  ├── Login / Registration                 │
│  ├── Home (Online/Offline toggle)         │
│  ├── Ride Request (Accept/Reject)         │
│  ├── Navigation (Turn-by-turn)            │
│  ├── Trip Progress                        │
│  └── Earnings Dashboard                  │
├──────────────────────────────────────────┤
│  Business Logic (ViewModel/UseCase)       │
│  ├── LocationManager                     │
│  ├── RideStateMachine                    │
│  ├── OfflineQueueManager                 │
│  └── MQTTConnectionManager              │
├──────────────────────────────────────────┤
│  Data Layer                               │
│  ├── MQTT Client (Paho/HiveMQ)           │
│  ├── Local Database (Room/CoreData)       │
│  ├── REST API Client (Retrofit/Alamofire) │
│  └── Offline Action Queue (SQLite)        │
├──────────────────────────────────────────┤
│  Platform Layer                           │
│  ├── Foreground Service (Android)         │
│  ├── Background Task (iOS)               │
│  ├── GPS Provider                         │
│  └── Battery Optimizer                   │
└──────────────────────────────────────────┘
```

### Android - Foreground Service (Critical)

```kotlin
// === LocationForegroundService.kt ===
// Giữ app chạy ngầm với notification cố định

class LocationForegroundService : Service() {
    
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var mqttClient: MqttAndroidClient
    private lateinit var offlineQueue: OfflineActionQueue
    
    override fun onCreate() {
        super.onCreate()
        
        // 1. Tạo Foreground notification (BẮT BUỘC trên Android 8+)
        val notification = createPersistentNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // 2. Khởi tạo GPS với cài đặt tối ưu
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            3000  // 3 giây / lần
        ).apply {
            setMinUpdateIntervalMillis(2000)
            setMaxUpdateDelayMillis(5000)
            setWaitForAccurateLocation(false) // Không chờ GPS chính xác 100%
        }.build()
        
        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            locationCallback,
            Looper.getMainLooper()
        )
    }
    
    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            
            // Gửi qua MQTT
            if (mqttClient.isConnected) {
                publishLocation(location)
            } else {
                // OFFLINE-FIRST: Lưu vào queue, sync sau
                offlineQueue.enqueue(LocationAction(
                    lat = location.latitude,
                    lng = location.longitude,
                    heading = location.bearing,
                    speed = location.speed,
                    timestamp = System.currentTimeMillis()
                ))
            }
        }
    }
    
    // Chống bị kill bởi OS
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY  // ← Tự restart nếu bị kill
    }
}
```

### iOS - Background Location

```swift
// === LocationManager.swift ===

class DriverLocationManager: NSObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    private let mqttClient: CocoaMQTT5
    private let offlineQueue: OfflineActionQueue
    
    func startTracking() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // meters
        locationManager.allowsBackgroundLocationUpdates = true  // ← KEY
        locationManager.pausesLocationUpdatesAutomatically = false // ← KEY
        locationManager.showsBackgroundLocationIndicator = true
        
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let payload: [String: Any] = [
            "lat": location.coordinate.latitude,
            "lng": location.coordinate.longitude,
            "heading": location.course,
            "speed": location.speed,
            "ts": Int(Date().timeIntervalSince1970)
        ]
        
        if mqttClient.connState == .connected {
            publishToMQTT(payload)
        } else {
            offlineQueue.enqueue(payload)
        }
    }
}
```

### Battery Optimization Strategy

```
┌────────────────────────────────────────────────┐
│ GPS Frequency Adaptation                        │
├────────────────────────────────────────────────┤
│                                                 │
│ Trạng thái: WAITING (chờ cuốc)                 │
│ → GPS: mỗi 10 giây, accuracy: BALANCED         │
│ → MQTT: gửi mỗi 15 giây                        │
│                                                 │
│ Trạng thái: APPROACHING (đang đến đón khách)   │
│ → GPS: mỗi 3 giây, accuracy: HIGH              │
│ → MQTT: gửi mỗi 3 giây                         │
│                                                 │
│ Trạng thái: IN_TRIP (đang chở khách)            │
│ → GPS: mỗi 2 giây, accuracy: HIGH              │
│ → MQTT: gửi mỗi 2 giây                         │
│                                                 │
│ Trạng thái: OFFLINE                             │
│ → GPS: TẮT                                     │
│ → MQTT: Disconnect                              │
└────────────────────────────────────────────────┘
```

---

## 2. Rider App - Cross-platform (Flutter/React Native)

### Tại sao Cross-platform được?

- Khách hàng **không cần chạy ngầm** liên tục
- Mở app → Đặt xe → Theo dõi → Trả tiền → Đóng app
- UI/UX bản đồ render mượt mà trên cả Flutter và React Native
- **1 codebase = 2 platforms** → Tiết kiệm 40-60% thời gian dev

### Kiến trúc Rider App

```
┌──────────────────────────────────────────┐
│              Rider App                    │
├──────────────────────────────────────────┤
│  Screens                                  │
│  ├── Home (Map + Booking)                 │
│  ├── Ride Tracking (Live map)             │
│  ├── Chat with Driver                     │
│  ├── Payment                              │
│  ├── Trip History                         │
│  └── Profile & Settings                  │
├──────────────────────────────────────────┤
│  State Management                         │
│  ├── BLoC/Riverpod (Flutter)             │
│  ├── Redux/Zustand (React Native)         │
│  └── WebSocket State                      │
├──────────────────────────────────────────┤
│  Services                                 │
│  ├── WebSocket Client (Socket.io)         │
│  ├── REST API Client                      │
│  ├── Map SDK (Mapbox/Goong)               │
│  ├── Push Notification (FCM/APNs)         │
│  └── Payment SDK                          │
└──────────────────────────────────────────┘
```

### Flutter Example: Live Tracking

```dart
class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  const RideTrackingScreen({required this.rideId});
  
  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  late IO.Socket socket;
  LatLng? driverPosition;
  String rideStatus = 'driver_arriving';
  int etaMinutes = 0;
  
  @override
  void initState() {
    super.initState();
    _connectSocket();
  }
  
  void _connectSocket() {
    socket = IO.io('wss://api.xebuonho.vn/rides', 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': AuthService.token})
        .build()
    );
    
    socket.onConnect((_) {
      socket.emit('subscribe:ride', widget.rideId);
    });
    
    // Live driver location → animate car on map
    socket.on('driver:location', (data) {
      setState(() {
        driverPosition = LatLng(data['lat'], data['lng']);
        etaMinutes = data['eta'] ~/ 60;
      });
      _animateMarker(driverPosition!);
    });
    
    // Ride status updates
    socket.on('ride:status', (data) {
      setState(() => rideStatus = data['status']);
      if (data['status'] == 'arrived') {
        _showNotification('Tài xế đã đến!');
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with driver marker
          MapWidget(driverPosition: driverPosition),
          // ETA overlay
          Positioned(
            bottom: 0,
            child: RideInfoCard(
              status: rideStatus,
              eta: etaMinutes,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}
```

---

## Kiểm thử (Testing Strategy)

| Layer | Công cụ | Focus |
|-------|---------|-------|
| Unit test | JUnit/XCTest/Flutter Test | Business logic, state machine |
| Integration | Espresso/XCUITest | GPS flow, MQTT reconnect |
| E2E | Detox/Appium | Full booking flow |
| Performance | Android Profiler/Instruments | Battery drain, memory leaks |
| Network | Charles Proxy | Offline scenarios, slow network |
