# vdb_rpiOs (VDP Mobile App)

This repository contains a Flutter mobile application used for a Video Door Phone (VDP) workflow:
- OTP-based user authentication
- Device selection and binding
- BLE onboarding for Wi-Fi provisioning
- Remote unlock and alerting
- Live stream via Janus/WebRTC
- User management actions
- Activity log viewing
- Firebase Realtime Database + FCM integration

---

## 1) Feature Overview

### Authentication & Session
- OTP request and verification flow
- Access token + refresh token lifecycle management
- Local persistence of session state
- Automatic refresh path and logout handling

### Device Lifecycle
- Device selection UI
- Binding selected device path to runtime state
- Firebase writes for token + FCM routing
- Device connectivity and Wi-Fi state checks

### BLE Onboarding
- Permission handling (Bluetooth/location/notification-related)
- BLE scanning and filtering
- Device connection and characteristic communication
- Wi-Fi credentials send + response wait flow

### Connected Experience
- Unlock door action
- Emergency/doorbell notification trigger
- Stream screen launch and playback controls
- User operations (add/view/verify/delete)
- Activity logs with pagination

### Notifications
- Foreground, background, and terminated notification handling
- Local notification display and tap-routing
- Route-aware navigation decisions (`connected` vs `stream`)

---

## 2) Project Architecture

```text
lib/
├── main.dart                    # Bootstrap, notifications, app-level routing
├── screens/                     # App screens (feature flows)
├── utils/                       # Core business/network/device logic
└── widgets/                     # Reusable UI components
```

### Main layers
- **UI Layer (screens/widgets):** renders flows and triggers actions.
- **State Layer (`LoaderProvider`):** stores shared state and notifies listeners.
- **Integration Layer (`utils/*`):**
  - REST API (auth/lock)
  - Firebase (RTDB + notifications)
  - BLE
  - Janus/WebRTC
  - WebSocket utility for device/user command streams

---

## 3) Core Runtime Flows

### A) Login and token lifecycle
1. User enters phone number in `LogInScreen`.
2. `WebApi.requestOTP()` requests OTP.
3. User enters OTP.
4. `WebApi.verifyOTP()` verifies and stores tokens.
5. App persists tokens and timestamps in `SharedPreferences`.
6. On startup, `SplashScreen._initializeApp()` validates token state and routes accordingly.
7. If access token is expired but refresh token is valid, `WebApi.useRefreshTokenToGetAccessToken()` refreshes access token.
8. If refresh token is expired/invalid, app logs out and routes to onboarding.

### B) Device selection and binding
1. Device selected in `DevicesListScreen`.
2. Device name and Firebase path are saved in `LoaderProvider`.
3. `LandingScreen._initializeDevice()` checks token validity and binds tokens/FCM token to selected device path in Firebase.
4. `FbUtils.backgroundListen()` starts realtime listening for device updates.

### C) BLE onboarding
1. User scans devices from `HomeScreen`.
2. `BleUtil` handles permission checks and scan lifecycle.
3. User chooses BLE device and opens Wi-Fi configuration.
4. `BleUtil.sendWiFiCredentialsAndWaitForResponse()` sends `SSID,password` and waits for response notifications.
5. On success, app transitions to connected/device flow.

### D) Streaming
1. `VideoStreamScreen` creates `JanusWebRTCClient`.
2. Client opens WebSocket, creates Janus session, attaches plugin.
3. Stream is watched and JSEP/ICE negotiation is handled.
4. Remote media is rendered in RTC renderer widgets.

### E) Logs
1. `LogsScreen._loadInitialLogs()` loads first page from Firestore.
2. `LogsScreen._loadMoreLogs()` performs paginated loading.
3. Cards display user/activity/status/timestamp and optional image preview.

---

## 4) Function-Level Documentation

Below is a file-by-file function summary of the source in `lib/`.

## `lib/main.dart`
- `_firebaseMessagingBackgroundHandler(RemoteMessage message)`: Initializes Firebase/notification plumbing in background isolate and maps incoming data payload to route-oriented local notification.
- `handleNotificationResponse(NotificationResponse response)`: Handles notification taps and routes app to connected or stream path.
- `_showNotification(String title, String body, {String? payload})`: Displays local Android notification with optional route payload.
- `_initLocalNotifications()`: Initializes local notification plugin and channel.
- `main()`: App bootstrap; initializes Firebase, sets FCM handlers, injects `LoaderProvider`, starts app.
- `_navigateToConnected()`: Routes to connected screen immediately if navigation context exists, otherwise defers via flag.
- `_navigateToStream()`: Routes to stream or connected screen depending on app lifecycle state/context availability.
- `_MyAppState.initState()`: Registers lifecycle observer, FCM listeners, local notification launch handling, and startup navigation checks.
- `_MyAppState.didChangeAppLifecycleState(...)`: Triggers pending-navigation reconciliation on resume.
- `_MyAppState._checkForPendingNavigation()`: Executes deferred notification-driven navigation once context is ready.
- `_MyAppState._storeFcmTokenLocally()`: Fetches current FCM token and stores in provider for later device binding.
- `_MyAppState.dispose()`: Removes lifecycle observer.
- `_MyAppState.build(...)`: Builds `MaterialApp` with global navigator key and splash entry.

## `lib/utils/loader_provider.dart`
- `setStreamSubscribed(bool)`: Tracks stream-subscription state.
- `setSurvailanceMode(bool)`: Tracks surveillance mode flag.
- `setWifiState(bool)`: Updates current wifi status flag.
- `showLoader()/hideLoader()`: Toggles loading indicator state.
- `setMacAddress(String)`: Stores selected/active device MAC.
- `lockID` setter: Stores lock ID for lock actions.
- `setDeviceName(String)`: Stores selected device display name.
- `setFirebasePath(String)`: Stores selected Firebase device path.
- `setIp(String)`: Stores current IP details from device data.
- `setFcmToken(String)`: Stores app FCM token.
- `setSelectedUser(String, String)`: Stores selected user metadata for user actions.
- `clearSelection()`: Clears current user selection.
- `otpSent`, `otp`, `phoneNumber`, `accessToken`, `refreshToken` setters: Session/auth flow state mutators.

## `lib/utils/web_api_brain.dart`
- `requestOTP(BuildContext)`: Sends OTP request for current phone number.
- `verifyOTP(BuildContext, otp)`: Verifies OTP, extracts tokens, persists session, routes to device list.
- `_saveTokensToPreferences(String, String)`: Persists token values and timestamps.
- `loadTokensFromPreferences()`: Loads stored tokens and applies expiry policy.
- `clearAllTokens()`: Clears local tokens and removes device-path tokens from Firebase if path is known.
- `clearTokensFromPreferences()`: Convenience wrapper for token clearing.
- `logoutUser(BuildContext)`: Clears session/provider state and routes to onboarding.
- `getLockList(BuildContext)`: Fetches lock list and stores active lock ID.
- `unlockDoor(BuildContext)`: Sends unlock command and returns HTTP status semantics.
- `sendNotification(BuildContext)`: Sends emergency/doorbell type alert for lock.
- `useRefreshTokenToGetAccessToken(BuildContext)`: Refreshes access token from refresh token and updates local/firebase state.

## `lib/utils/firebase_core_utils.dart`
- `backgroundListen(Future<FirebaseApp>, BuildContext, String fbPath)`: Starts RTDB listener at selected path, updates provider state, returns first snapshot payload.
- `handler(RemoteMessage)`: Basic background message handler hook.
- `fbPushNotification()`: Requests FCM permissions and registers background handler.
- `readIpType(String fbPath)`: Reads `ip_type` from RTDB.
- `readWifiState(String fbPath)`: Reads `wifi_state` from RTDB.
- `getNotifPermission()`: Requests runtime notification permissions.
- `cancelBackgroundListen()`: Cancels active background DB subscription.

## `lib/utils/ble_util.dart`
- `getPermissions()`: Requests BLE and related runtime permissions.
- `checkBluetoothReady()`: Validates preconditions before scan/connect (permission/service/adapter).
- `findBleState()`: Subscribes to adapter state and reacts to on/off transitions.
- `_handleBluetoothOff(bool)`: Handles Bluetooth-off scenario and scan stop/reset.
- `startScan({Duration timeout})`: Starts BLE scan with timeout and scan-state tracking.
- `stopScan()`: Stops active scan and timers.
- `connectToDevice(...)`: Connects to BLE device with retry logic and service discovery.
- `isDeviceConnected(String)`: Checks current connection state for device.
- `disconnectFromDevice(String)`: Disconnects from active BLE link.
- `printUniqueResults()`: Logs unique scan result details useful during onboarding diagnostics.
- `sendData(BluetoothDevice, data)`: Writes payload to writable characteristic.
- `readData(BluetoothDevice)`: Subscribes to notify characteristics and reads updates.
- `sendWiFiCredentialsAndWaitForResponse(...)`: Sends Wi-Fi credentials and waits for notification response/timeout.
- `subscribeToChar(BluetoothDevice)`: Waits for characteristic notification payload and returns decoded string.
- `dispose()`: Cleans scan/stream/timer resources.

## `lib/utils/janus_webrtc_client.dart`
- `connect()`: Opens Janus WebSocket, installs listeners, creates session, starts keepalive.
- `_handleWebSocketMessage(dynamic)`: Parses and routes Janus protocol messages.
- `_handleJanusEvent(Map<String, dynamic>)`: Handles Janus event payloads.
- `_handleStreamingEvent(Map<String, dynamic>)`: Handles streaming-plugin event states.
- `_handleJSEP(Map<String, dynamic>)`: Handles remote SDP and answer flow.
- `_addRemoteIceCandidate(Map<String, dynamic>)`: Adds remote ICE candidates to peer connection.
- `_createSession()`: Requests Janus session creation.
- `attachToStreamingPlugin()`: Attaches Janus streaming plugin and stores handle.
- `listStreams()`: Retrieves available streams from Janus.
- `watchStream(int)`: Starts watch flow for target stream.
- `startStream(int)`: Sends stream start command.
- `stopStream()`: Sends stream stop command.
- `pauseStream()`: Sends stream pause command.
- `switchStream(int)`: Switches current stream.
- `_createPeerConnection()`: Builds and configures WebRTC peer connection and callbacks.
- `_sendMessage(Map<String, dynamic>)`: Sends Janus protocol message with transaction handling.
- `_generateTransaction()`: Generates transaction ID string for Janus message correlation.
- `keepAlive()`: Sends periodic Janus keepalive.
- `_startKeepAlive()`: Starts keepalive timer loop.
- `disconnect()`: Closes session/pc/socket resources and stream controllers.
- `dispose()`: Full resource cleanup wrapper.

## `lib/utils/websocket_util.dart`
- `connect(String ip)`: Connects singleton WebSocket to endpoint and starts buffer management.
- `_startBufferClearTimer()`: Maintains bounded receive buffer.
- `close()`: Closes socket/controller/timer resources.
- `dispose()`: Calls close.

## `lib/screens/splash_screen.dart`
- `initState()`: Triggers startup initialization.
- `_initializeApp()`: Resolves persisted token state and routes to onboarding or device flow.
- `build(...)`: Renders splash/loading UI.

## `lib/screens/onboarding_screen.dart`
- `build(...)`: Renders branding, policy links, and entry CTA to configuration/login.

## `lib/screens/log_in_screen.dart`
- `initState()/dispose()`: Screen lifecycle setup/cleanup.
- `build(...)`: Renders phone/OTP form states and calls OTP request/verify actions.

## `lib/screens/devices_list_screen.dart`
- `build(...)`: Renders available device cards and stores selected device context before navigating onward.

## `lib/screens/landing_screen.dart`
- `initState()/dispose()/didChangeDependencies()`: Initializes and cleans animation/listener-related state.
- `_initializeDevice()`: Coordinates token check + device binding startup.
- `_checkTokenValidity()`: Ensures usable access token or triggers refresh/logout.
- `_bindToDevice()`: Pushes session + FCM metadata to selected firebase path and starts listeners.
- `_onItemTapped(int)`: Handles bottom-nav/tab state transitions.
- `checkWifiConnection()`: Verifies device wifi handshake and routes on failure/success.
- `_skipWifiCheck()`: Bypass helper for wifi-check transition path.
- `_buildWifiCheckingScreen()`: Builds wifi-check loading/transition UI.
- `build(...)`: Main landing container with tabs and animated states.

## `lib/screens/home_screen.dart`
- `build(...)`: BLE scan list UI, scan trigger, and navigation to Wi-Fi config for selected device.

## `lib/screens/wifi_configuration_screen.dart`
- `build(...)`: Hosts credentials form for selected BLE device and handles back/disconnect behavior.

## `lib/screens/connected_screen.dart`
- `initState()/didChangeDependencies()`: Initializes connected-state dependencies.
- `handleUnlock()`: Sends unlock action and controls temporary unlocked UI state.
- `checkWifiConnection()`: Re-checks wifi state and routes to recovery on disconnect.
- `build(...)`: Main connected dashboard and action navigation.

## `lib/screens/video_stream_screen.dart`
- `_formatDuration(int)`: Utility for recording elapsed-time display.
- `_connect()`: Connects Janus client and initializes stream session data.
- `_watchStream()`: Starts stream watch flow.
- `connectOnPageInit()`: Startup helper to connect automatically.
- `_startStream()`: Stream-start wrapper call path.
- `_initRenderers()`: Initializes RTC renderers/controllers.
- `initState()/didChangeDependencies()/dispose()`: Lifecycle setup/cleanup.
- `build(...)`: Stream player UI, controls, and view state.

## `lib/screens/users_screen.dart`
- `initState()/dispose()`: Subscribes/unsubscribes screen-level stream resources.
- `build(...)`: Hosts user-management action widgets.

## `lib/screens/settings_screen.dart`
- `build(...)`: Renders settings options (users/logs/logout/navigation actions).

## `lib/screens/logs_screen.dart`
- `initState()/dispose()`: Initializes pagination and cleanup.
- `_loadInitialLogs()`: Loads first log page and state flags.
- `_loadMoreLogs()`: Loads subsequent log pages.
- `_refreshLogs()`: Pull-to-refresh path.
- `_isValidBase64(String)`: Validates image payload format.
- `_getStatusCode(String)`: Maps activity text to status code/category.
- `_formatTimestamp(String?)`: Normalizes timestamp display string.
- `_buildLoadingState()/_buildLoadMoreButton()/_buildEmptyState()`: Reusable UI states.
- `build(...)`: Logs list UI, pagination trigger, and empty/loading handling.

## `lib/screens/wifi_disconnected_screen.dart`
- `build(...)`: Recovery screen for wifi disconnected state with configure/retry actions.

## `lib/widgets/*`
- `BlePromptStack.build(...)`: Onboarding CTA block.
- `ConnectedScreenUnlockCard.build(...)`: Unlock card rendering and status visuals.
- `ConnectedScreenUnlockCard._buildWifiIndicator(bool)`: Wi-Fi indicator rendering.
- `DeleteUserWidget.build(...)`: Delete-user UI and action trigger.
- `ViewUsersWidget._getUsersStream()`: Firestore stream for users list.
- `ViewUsersWidget.build(...)`: User list UI binding.
- `WifiCredentialsForm.build(...)`: SSID/password form and provisioning action.
- `VerifyUserWidget._watchStream()/connectOnPageInit()/initState()/didChangeDependencies()/dispose()/build(...)`: Verify-user interaction + stream wiring lifecycle.
- `ConfigTiles.build(...)`: Reusable settings/action tile.
- `AddUserWidget._watchStream()/connectOnPageInit()/initState()/didChangeDependencies()/dispose()/build(...)`: Add-user interaction + stream wiring lifecycle.
- `RoomInfoCard.build(...)`: Device info card view.
- `PrivacyConditionsHyper.build(...)`: Privacy/terms link widget.
- `HomeScreenFuncButton.build(...)`: Reusable functional button.
- `HomeScreenHomeWidget.build(...)`: Home content widget.
- `FullScreenVideoView.initState()/dispose()/build(...)`: Full-screen stream view lifecycle + rendering.
- `UserCardRow.build(...)`: User-row rendering widget.
- `DeleteUsersDropdownWidget._getUsersStream()/build(...)`: Dropdown data stream and rendering.
- `IpPortTextfield.initState()/build(...)`: Input widget initialization/rendering for login flows.
- `ActivityLogCard._getStatusLabel()/_showImageDialog(...)/build(...)`: Log card status formatting, image preview dialog, and rendering.
- `MenuWidget.build(...)`: Menu/navigation widget.
- `BrandLogoName.build(...)`: Branding header.
- `ScanCard.build(...)`: BLE scan result card rendering.

---

## 5) Security-Safe Documentation Notes

This documentation intentionally avoids exposing secret values.

### Documented safely
- Feature behavior and architecture
- Data flow patterns
- Method responsibilities
- Integration boundaries (REST/Firebase/BLE/WebRTC)

### Not exposed in docs
- Real credential values (API keys, tokens, user data)
- Any private identifiers beyond source-level non-secret naming

### Important hardening recommendations
- Move sensitive keys/configuration out of source code into secure config management.
- Replace plain persistent token storage with encrypted secure storage.
- Redact sensitive values in logs.
- Enforce strict backend and Firebase/Firestore security rules per device/user scope.

---

## 6) Developer Notes

- State sharing is centralized through `LoaderProvider`.
- Most external interactions are concentrated in `lib/utils/*`.
- Screen files orchestrate flow; widgets focus on reusable rendering/action blocks.
- For onboarding and connectivity issues, start tracing from:
  - `home_screen.dart` → `wifi_configuration_screen.dart` → `landing_screen.dart`
- For auth/session issues, start tracing from:
  - `splash_screen.dart` + `log_in_screen.dart` + `web_api_brain.dart`
