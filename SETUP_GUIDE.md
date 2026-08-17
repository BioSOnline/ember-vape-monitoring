# EMBER - Quick Setup Guide

## 🚀 Quick Start

### 1. Install Flutter Dependencies
```bash
cd C:\Users\ADNAN\Documents\EMBER
flutter pub get
```

### 2. Configure Supabase

#### Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Navigate to **SQL Editor**
4. Copy and paste the contents of `supabase/schema.sql`
5. Run the SQL script

#### Update Configuration
Edit `lib/core/config/supabase_config.dart`:
```dart
static const String supabaseUrl = 'https://your-project.supabase.co';
static const String supabaseAnonKey = 'your-anon-key-here';
```

Find these values in your Supabase project:
- **Project Settings** → **API** → **Project URL**
- **Project Settings** → **API** → **anon/public** key

### 3. Add TFLite Model

The app expects a TensorFlow Lite model at `assets/models/puff_detection.tflite`.

**For now** (development/testing):
- The app will run but puff detection won't work until the model is exported
- You may see an error in logs if the asset is missing

**To add the actual model:**
1. If you already have trained YOLO weights, skip training and go straight to export
2. From WSL, run `./export_model.sh`
3. The script exports INT8 TFLite from `runs/detect/train/weights/best.pt` and copies it to `assets/models/puff_detection.tflite`
4. Rebuild the app

### 4. Run the App

Connect an Android device or start an emulator, then:
```bash
flutter run
```

Or use VS Code:
- Press **F5** to run in debug mode
- Select your target device

---

## 📱 Testing Without Model

You can test the app without the TFLite model:
- ✅ Home screen will load
- ✅ Today's puff count (from Supabase)
- ✅ Manual puff entry (when implemented)
- ❌ Live camera detection won't work (requires model)

---

## 🔧 Troubleshooting

### "Supabase initialization failed"
- Check your internet connection
- Verify `supabaseUrl` and `supabaseAnonKey` are correct
- Ensure Supabase project is active

### "Failed to load TFLite model"
- Expected if you haven't added the model yet
- App will still run, just without detection capability
- See "Add TFLite Model" section above

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📊 Current Features

### ✅ Implemented
- Supabase integration
- Data models (PuffEvent, Session, AddictionScore)
- Home screen UI
- Services (Supabase, Notification, ML logic)
- Database schema with RLS

### 🔄 Coming Soon
- Live camera detection screen
- Dashboard with analytics charts
- Onboarding flow
- Manual puff entry
- Authentication screens
- Settings

---

## 📞 Contact

**MITE CSE Final Year Project**  
**Guide:** Dr. Rejeesh Rayaroth  
**Team:** Abdullah Kola, Adnan Irfan Rahiman, Ayush C. Umeshan, Eashan Y. Poojary
