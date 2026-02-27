# 📡 Offline-First cho Tài xế

> **Nguyên tắc #2**: Tài xế bấm "Đã đón khách" lúc mất sóng → App lưu lại → Có mạng tự sync. **KHÔNG BAO GIỜ** báo lỗi mạng vào mặt tài xế.

## Vấn đề

```
Tài xế đi vào hầm/vùng lõm sóng
    ↓
Bấm "Đã đón khách"
    ↓
❌ KHÔNG CÓ OFFLINE-FIRST:
    → Hiện popup "Lỗi mạng, vui lòng thử lại"
    → Tài xế bực mình, bấm lại nhiều lần
    → Cuốc xe "đứng im" trên server
    → Khách hàng thấy tài xế "đứng im" trên bản đồ
    → UX tệ, mất khách

✅ CÓ OFFLINE-FIRST:
    → App lưu hành động vào local queue
    → UI update ngay lập tức (optimistic)
    → Khi có mạng → sync ngầm với server
    → Tài xế không biết mạng đã mất!
```

## Kiến trúc Offline Queue

```
┌──────────────────────────────────────────────────┐
│           Driver App Offline Architecture         │
├──────────────────────────────────────────────────┤
│                                                   │
│  User Action (bấm nút)                           │
│       ↓                                           │
│  ┌────────────────┐  ┌─────────────────────┐     │
│  │ Local State    │  │ Offline Action Queue │     │
│  │ (UI updates    │  │ (SQLite / Room)      │     │
│  │  immediately)  │  │                      │     │
│  └────────────────┘  │ ┌─────────────────┐  │     │
│       ↓              │ │ action: PICK_UP │  │     │
│  UI hiển thị "Đã     │ │ ride_id: xxx    │  │     │
│  đón khách" ngay     │ │ timestamp: ...  │  │     │
│                      │ │ status: PENDING │  │     │
│                      │ └─────────────────┘  │     │
│                      └──────────┬───────────┘     │
│                                 ↓                 │
│                    NetworkMonitor                  │
│                    ┌─────────────────┐             │
│                    │ Online? ──→ YES │             │
│                    │    ↓            │             │
│                    │ SyncManager     │             │
│                    │ Process queue   │             │
│                    │ in FIFO order   │             │
│                    └────────┬────────┘             │
│                             ↓                     │
│                    MQTT / REST API                  │
│                    Send to Server                  │
│                             ↓                     │
│                    Mark action as SYNCED            │
└──────────────────────────────────────────────────┘
```

## Implementation

### 1. Offline Action Queue (Android/Kotlin)

```kotlin
// === OfflineAction.kt ===
@Entity(tableName = "offline_actions")
data class OfflineAction(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val actionType: String,        // "UPDATE_STATUS", "UPDATE_LOCATION", "ACCEPT_RIDE"
    val rideId: String?,
    val payload: String,           // JSON payload
    val timestamp: Long = System.currentTimeMillis(),
    val retryCount: Int = 0,
    val maxRetries: Int = 5,
    val status: String = "PENDING" // PENDING, SYNCING, SYNCED, FAILED
)

// === OfflineActionDao.kt ===
@Dao
interface OfflineActionDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(action: OfflineAction)
    
    @Query("SELECT * FROM offline_actions WHERE status = 'PENDING' ORDER BY timestamp ASC")
    suspend fun getPendingActions(): List<OfflineAction>
    
    @Query("UPDATE offline_actions SET status = :status WHERE id = :id")
    suspend fun updateStatus(id: String, status: String)
    
    @Query("DELETE FROM offline_actions WHERE status = 'SYNCED'")
    suspend fun clearSynced()
}

// === OfflineQueueManager.kt ===
class OfflineQueueManager(
    private val dao: OfflineActionDao,
    private val apiClient: ApiClient,
    private val mqttClient: MqttClient,
    private val connectivityManager: ConnectivityManager
) {
    // Enqueue action (gọi khi tài xế thực hiện bất kỳ hành động nào)
    suspend fun enqueueAction(type: String, rideId: String?, payload: Map<String, Any>) {
        val action = OfflineAction(
            actionType = type,
            rideId = rideId,
            payload = Gson().toJson(payload)
        )
        dao.insert(action)
        
        // Thử sync ngay nếu có mạng
        if (isOnline()) {
            processQueue()
        }
    }
    
    // Process queue khi có mạng trở lại
    suspend fun processQueue() {
        val pendingActions = dao.getPendingActions()
        
        for (action in pendingActions) {
            try {
                dao.updateStatus(action.id, "SYNCING")
                
                when (action.actionType) {
                    "UPDATE_STATUS" -> syncStatusUpdate(action)
                    "UPDATE_LOCATION" -> syncLocationBatch(action)
                    "ACCEPT_RIDE" -> syncAcceptRide(action)
                    "COMPLETE_RIDE" -> syncCompleteRide(action)
                }
                
                dao.updateStatus(action.id, "SYNCED")
            } catch (e: Exception) {
                if (action.retryCount >= action.maxRetries) {
                    dao.updateStatus(action.id, "FAILED")
                    reportFailure(action, e)
                } else {
                    dao.insert(action.copy(
                        retryCount = action.retryCount + 1,
                        status = "PENDING"
                    ))
                }
            }
        }
        
        dao.clearSynced()
    }
    
    // Network callback
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            // Có mạng trở lại → sync immediately
            CoroutineScope(Dispatchers.IO).launch {
                processQueue()
            }
        }
    }
    
    fun startMonitoring() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        connectivityManager.registerNetworkCallback(request, networkCallback)
    }
}
```

### 2. Optimistic UI Update

```kotlin
// === TripViewModel.kt ===
class TripViewModel(
    private val offlineQueue: OfflineQueueManager
) : ViewModel() {
    
    private val _tripStatus = MutableStateFlow(TripStatus.DRIVER_ARRIVING)
    val tripStatus: StateFlow<TripStatus> = _tripStatus
    
    // Tài xế bấm "Đã đón khách"
    fun onPickupPassenger(rideId: String) {
        // 1. UPDATE UI NGAY LẬP TỨC (dù offline)
        _tripStatus.value = TripStatus.IN_PROGRESS
        
        // 2. Queue action để sync sau
        viewModelScope.launch {
            offlineQueue.enqueueAction(
                type = "UPDATE_STATUS",
                rideId = rideId,
                payload = mapOf(
                    "status" to "in_progress",
                    "picked_up_at" to System.currentTimeMillis(),
                    "location" to getCurrentLocation()
                )
            )
        }
    }
    
    // Tài xế bấm "Hoàn thành chuyến"
    fun onCompleteTrip(rideId: String) {
        // 1. Update UI
        _tripStatus.value = TripStatus.COMPLETED
        
        // 2. Queue action (QoS 2 equivalent - critical)
        viewModelScope.launch {
            offlineQueue.enqueueAction(
                type = "COMPLETE_RIDE",
                rideId = rideId,
                payload = mapOf(
                    "status" to "completed",
                    "completed_at" to System.currentTimeMillis(),
                    "final_location" to getCurrentLocation()
                )
            )
        }
    }
}
```

### 3. Conflict Resolution

```
Server nhận action với timestamp cũ hơn current state:

Ví dụ:
  Server status: IN_PROGRESS (updated 10:05)
  Offline action: PICKED_UP (timestamp 10:03)

Cách xử lý:
  ┌─────────────────────────────────────────────┐
  │ Rule 1: Timestamp-based (Last Write Wins)    │
  │   → Giữ state mới nhất                      │
  │                                              │
  │ Rule 2: State Machine validation              │
  │   → Chỉ chấp nhận transition hợp lệ         │
  │   → PICKED_UP khi đã IN_PROGRESS → REJECT   │
  │   → IN_PROGRESS khi ARRIVED → ACCEPT         │
  │                                              │
  │ Rule 3: Server always wins cho critical ops  │
  │   → Payment, ride assignment                 │
  │   → Client reconcile upon sync               │
  └─────────────────────────────────────────────┘
```

### 4. Location Batch Sync

```kotlin
// Khi offline, GPS vẫn chạy, lưu locations vào buffer
class LocationBuffer(private val dao: LocationDao) {
    
    private val buffer = mutableListOf<LocationPoint>()
    
    fun addLocation(lat: Double, lng: Double, heading: Float, speed: Float) {
        buffer.add(LocationPoint(lat, lng, heading, speed, System.currentTimeMillis()))
        
        // Flush to SQLite mỗi 10 points
        if (buffer.size >= 10) {
            flush()
        }
    }
    
    // Khi có mạng: gửi batch tất cả locations đã buffer
    suspend fun syncBatch(mqttClient: MqttClient, driverId: String) {
        val points = dao.getUnsynced()
        if (points.isEmpty()) return
        
        // Gửi batch qua MQTT (server sẽ fill gap trên bản đồ khách)
        val payload = Gson().toJson(mapOf(
            "driver_id" to driverId,
            "locations" to points,
            "offline_duration_ms" to (points.last().timestamp - points.first().timestamp)
        ))
        
        mqttClient.publish(
            "drivers/$driverId/location/batch",
            payload.toByteArray(),
            qos = 1
        )
        
        dao.markAllSynced()
    }
}
```

---

## Checklist triển khai

- [ ] Tạo `OfflineAction` Room entity
- [ ] Implement `OfflineQueueManager` với FIFO processing
- [ ] Implement `NetworkMonitor` callback
- [ ] Optimistic UI update cho tất cả trip actions
- [ ] Location buffer cho GPS khi offline
- [ ] Batch sync khi reconnect
- [ ] Conflict resolution rules
- [ ] Test scenarios: mất mạng 30s, 5 phút, 30 phút
- [ ] Test: bấm nút khi đang reconnect
