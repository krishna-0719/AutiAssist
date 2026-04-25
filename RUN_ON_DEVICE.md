# How to Run Care & Child App on Your Mobile Device (CPH2717)

## Prerequisites

Your device is: **CPH2717** (OPPO device)

### What You Need:
1. ✅ USB Cable (USB-C or Micro USB)
2. ✅ Android phone with USB debugging enabled
3. ✅ Flutter & Android SDK installed on your PC

---

## Step 1: Enable USB Debugging on Your Phone

1. Open **Settings** on your phone
2. Go to **About Phone**
3. Find **Build Number** and tap it **7 times** until you see "Developer Mode Enabled"
4. Go back to **Settings**
5. Open **Developer Options** (usually under System)
6. Enable **USB Debugging**
7. You may see a dialog asking to allow USB debugging - tap **Allow**

---

## Step 2: Connect Your Phone to PC via USB

1. **Connect** your phone to your computer with USB cable
2. **Select "File Transfer"** or **"File Transfer (MTP)"** when prompted on phone
3. Wait for the drivers to install (may take 30 seconds)

---

## Step 3: Run the App on Your Device

### Option A: Using Terminal (Recommended)

Open Command Prompt or PowerShell and run:

```bash
# Navigate to project
cd C:\Users\Neerajara\Desktop\care_child_v2

# Check if device is connected
flutter devices

# You should see your phone listed, like:
# CPH2717 (mobile) • 2e5d5c4... • android-arm64 • Android 13 (or higher)

# Get dependencies (first time only)
flutter pub get

# Run on your connected device
flutter run
```

### Option B: If Flutter Command Not Found

If `flutter` command doesn't work, try finding Flutter manually:

```bash
# Try using direct path (adjust based on your installation)
C:\Users\Neerajara\.puro\envs\stable\flutter\bin\flutter.bat devices

# Then run:
C:\Users\Neerajara\.puro\envs\stable\flutter\bin\flutter.bat run
```

### Option C: Using Android Studio (Easiest for Beginners)

1. Open **Android Studio**
2. Open your project folder: `C:\Users\Neerajara\Desktop\care_child_v2`
3. Wait for Gradle sync to complete
4. Look for **Run** button (green play icon) at the top
5. Select your device from dropdown if multiple connected
6. Click **Run**

---

## Step 4: What to Expect

Once you run the app:

1. **First Time (2-3 minutes):**
   - Flutter will build the APK
   - Install on your phone
   - Wait for "Launching..." message to complete

2. **App Launches:**
   - Parental Lock dialog should appear
   - Try default PIN: **1234**
   - Dashboard should load with your data

3. **Testing the Fixes:**
   - ✅ Try opening Symbol Management - dialog should be responsive
   - ✅ Try marking a request as done - should show spinner
   - ✅ Try deleting a request - should show feedback
   - ✅ Check that parental lock dialog fits on screen

---

## Troubleshooting

### Device Not Detected

```bash
# Restart ADB
adb kill-server
adb start-server

# List devices again
adb devices

# If still not showing, check:
# 1. USB cable is properly connected
# 2. File Transfer mode selected on phone
# 3. USB Debugging is enabled
# 4. Drivers installed (might take 2-3 minutes)
```

### Build Failed

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# If that doesn't work:
flutter clean
flutter pub get --offline
flutter run -v  # Show verbose output
```

### App Crashes on Launch

Check logs:
```bash
flutter run -v  # Run with verbose output
# Scroll through output to see error messages
```

### Need to see detailed logs

```bash
# View device logs in real-time
adb logcat | grep flutter
```

---

## Quick Command Reference

| Task | Command |
|------|---------|
| Check connected devices | `flutter devices` |
| Run on device | `flutter run` |
| Run with hot reload | `flutter run` (then press 'r' in terminal) |
| Stop the app | Press Ctrl+C in terminal |
| View device logs | `adb logcat` |
| Install APK directly | `adb install app.apk` |
| Uninstall app | `adb uninstall com.example.care_child_app` |

---

## After App is Running

### Test All Fixed Issues:

1. **Test Parental Lock Dialog:**
   - Open Settings
   - Dialog should display properly on screen
   - Try PIN: 1234
   - Text should not overflow

2. **Test Request Status Updates:**
   - Go to Requests
   - Tap "Mark Done" button
   - Should show loading spinner
   - Button should be disabled while updating

3. **Test Symbol Management:**
   - Open Symbols
   - Tap Edit on any symbol
   - Dialog should be responsive
   - Should not overflow on screen

4. **Test Dashboard:**
   - Go to Home/Dashboard
   - Check Live Requests section
   - Try marking requests as done
   - Should show loading feedback

---

## Hot Reload (Quick Testing)

While the app is running on your phone:

1. Make code changes on your PC
2. Press **'r'** in the terminal to hot reload
3. App updates on phone in ~1 second
4. Perfect for quick testing!

---

## Building for Release (After Testing)

Once everything works:

```bash
# Build release APK
flutter build apk --release

# APK will be at:
# C:\Users\Neerajara\Desktop\care_child_v2\build\app\outputs\apk\release\app-release.apk

# You can share this APK to install on other phones
```

---

## Still Having Issues?

Try these steps in order:

1. **Reconnect USB cable** - Disconnect and reconnect
2. **Restart phone** - Turn off and turn back on
3. **Restart PC** - Full restart of computer
4. **Check Android SDK** - Make sure it's properly installed
5. **Update drivers** - Check device manager for unknown devices
6. **Clean build** - Run `flutter clean` and `flutter pub get` again

---

**Once app is running on your phone, you'll see all the fixes in action!** 🚀

