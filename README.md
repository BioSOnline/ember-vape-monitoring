# EMBER — Early Monitoring of Behavioral & Environmental Risk
> **Smart Vape & Cigarette Usage Monitoring and Addiction Reduction System**  
> *Final Year Major Project (2025–2026) | Department of Computer Science & Engineering, MITE*

---

## 📌 Project Overview

**EMBER** is a mobile health (mHealth) and edge AI application developed as our final year engineering project. The goal of this project is to provide an automated, privacy-conscious way for users to track their smoking and vaping habits, understand their addiction triggers, and reduce nicotine consumption over time.

Most existing habit trackers require manual entry, which people often forget to do. Wearable-based alternatives often require expensive external hardware. EMBER addresses this by performing **on-device computer vision inference (YOLOv9)** to detect puff actions using the phone's front camera or uploaded video clips, paired with **machine learning models** that analyze behavioral patterns and forecast future craving windows.

---

## 🎯 Key Objectives

1. **Automated Puff Detection:** Detect hand-to-mouth vaping and smoking gestures in real time using edge computer vision without storing or streaming raw video.
2. **Behavioral Analytics:** Group detected puffs into discrete sessions, measure inter-puff intervals, and identify peak smoking hours.
3. **Addiction Risk Classification:** Calculate an objective addiction score using a Decision Tree model trained on usage frequency and temporal density.
4. **Craving Forecasting:** Predict when the user is likely to crave their next session using linear regression to trigger timely intervention reminders.
5. **Harm Reduction & Relief:** Provide instant craving mitigation tools such as guided 4-7-8 breathing exercises and habit delay timers.

---

## 💡 How It Works (System Architecture)

The system is split into three main layers: on-device perception, behavioral analysis, and cloud persistence.

```
+-------------------------------------------------------------------------+
|                              EMBER App (Flutter)                        |
|                                                                         |
|  [ Camera Feed / Video ] --> [ Background Dart Isolate (Pre-processing) ] |
|                                             |                           |
|                                             v                           |
|                              [ YOLOv9 TFLite Engine (Edge AI) ]         |
|                                             |                           |
|                                             v                           |
|                              [ Spatial & Dwell Filter ]                 |
|                                             |                           |
|                                  (Detected Puff Events)                 |
+---------------------------------------------+---------------------------+
                                              |
                                              v
+-------------------------------------------------------------------------+
|                         Behavioral Intelligence Engine                  |
|                                                                         |
|  • Decision Tree Classifier   --> Computes Addiction Level (Low/Med/High)|
|  • Linear Regression Model    --> Predicts Next Craving Window (Minutes)|
+---------------------------------------------+---------------------------+
                                              |
                                              v
+-------------------------------------------------------------------------+
|                         Supabase Cloud Backend                          |
|                                                                         |
|  • PostgreSQL Database with Row-Level Security (RLS)                    |
|  • Secure User Authentication & Metadata Sync (Timestamps & Counts only)|
+-------------------------------------------------------------------------+
```

---

## 📱 App Modules & Features

### 1. Detection Modes
- **Live Camera Detection:** Uses the front camera stream. Frames are fed to our quantized TFLite model. If hand-to-mouth contact exceeds our threshold dwell time, a puff event is logged.
- **Video Upload / Demo Analysis:** Allows users or evaluators to select a pre-recorded video or sample clip (`assets/samples/`) to test batch detection.
- **Manual Logging:** Fallback option to quickly tap and record a session manually when camera usage isn't practical.

### 2. Analytics Dashboard
- Daily, weekly, and monthly puff trends powered by `fl_chart`.
- Breakdown of session duration and average inter-puff intervals (in seconds).
- Active smoke-free streak counter and daily goal tracker.

### 3. ML Risk & Craving Engine
- **Addiction Scoring:** Requires at least 3 days of baseline data to classify severity into Low, Moderate, or High, identifying the primary contributing factor (e.g., tight puff clustering or high daily count).
- **Craving Predictor:** Requires 7 days of historical logs to calculate expected craving intervals and schedule local device push notifications.

### 4. Craving Relief Tools
- **Guided 4-7-8 Breathing:** An animated visual timer to guide slow diaphragmatic breathing and reduce acute craving anxiety.
- **Urge Management Tips:** Practical distraction and grounding techniques to delay the urge to smoke.
- **Theme Support:** Built-in dark and light mode themes with custom color palettes.

---

## 🔒 Privacy & Security Design

Because camera-based monitoring deals with sensitive personal data, EMBER is built with a strict **privacy-first approach**:
- **No Video Recording or Uploading:** Camera frames are processed strictly in RAM and immediately discarded after inference.
- **Metadata-Only Sync:** The database only stores anonymized behavioral metadata: timestamps, puff counts, session lengths, and model confidence scores.
- **Row-Level Security (RLS):** Supabase database policies ensure users can only read and write their own data.

---

## 🔬 Machine Learning Details

### 1. Computer Vision (Puff Detection)
- **Model:** YOLOv9-tiny fine-tuned on custom vape and smoking gesture datasets.
- **Quantization:** Exported to INT8 / Float32 TensorFlow Lite (`assets/models/puff_detection.tflite`) for mobile efficiency.
- **Threading:** Image normalization and tensor packing are processed in background Dart `Isolate` threads to prevent UI frame drops.
- **Training Results:** Achieved an **mAP50 of 83.47%** on the validation split.

### 2. Behavioral Models
- **Addiction Risk Assessment:** Decision Tree model evaluating 3 core metrics (Average daily puffs, Sessions per day, Average inter-puff interval in minutes).
- **Craving Prediction:** Linear regression analyzing temporal gaps between past sessions to estimate minutes until the next craving.

---

## 💻 Tech Stack

- **Mobile Framework:** Flutter 3.x (Dart 3.x)
- **Edge ML Inference:** `tflite_flutter`, `camera`, `image`
- **Backend & Auth:** Supabase (PostgreSQL with RLS)
- **Data Visualization:** `fl_chart`, `intl`
- **Notifications & Utilities:** `flutter_local_notifications`, `provider`, `uuid`
- **Model Training & Conversion:** Python, PyTorch, Ultralytics YOLOv9, ONNX, `onnx2tf`

---

## 📂 Codebase Structure

```
EMBER/
├── assets/
│   ├── models/                  # Quantized TFLite model file
│   │   └── puff_detection.tflite
│   └── samples/                 # Sample video files for testing
├── lib/
│   ├── core/                    # App constants, Supabase config, theme definitions
│   ├── models/                  # Data classes (PuffEvent, Session, AddictionScore, UserProfile)
│   ├── screens/                 # UI screens (Home, Dashboard, Detection, Video Upload, Relief)
│   ├── services/                # Backend API, ML algorithms, Native TFLite FFI bridge
│   ├── widgets/                 # Dialogs, custom charts, theme toggle buttons
│   └── main.dart                # App entry point
├── supabase/
│   └── schema.sql               # Database tables, triggers, indexes, and RLS policies
├── train_yolov9.py              # Script to train/fine-tune the YOLOv9 model
├── export.py                    # Script to convert YOLO weights to TFLite format
└── pubspec.yaml                 # Dependencies and asset declarations
```

---

## 🚀 Getting Started / Setup Guide

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (v3.10.8 or newer)
- Android device or emulator with camera support (or Windows desktop)
- Free [Supabase](https://supabase.com) account

### 2. Clone the Repository & Install Packages
```bash
git clone https://github.com/BioSOnline/ember-vape-monitoring.git
cd ember-vape-monitoring

flutter pub get
```

### 3. Database Configuration
1. Create a new Supabase project.
2. Go to the **SQL Editor** in Supabase.
3. Copy the contents of `supabase/schema.sql` and run the script to create tables (`users`, `sessions`, `puff_events`, `addiction_scores`) and RLS rules.
4. Create a `.env` file in the root directory:
   ```env
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your-anon-public-key
   ```

### 4. Running the App
```bash
# To run on a connected Android phone or emulator:
flutter run

# To run on Windows desktop:
flutter run -d windows
```

---

## 🛠️ Model Training & Export Workflow

If you want to retrain or export the YOLOv9 detection model:

```bash
# 1. Train YOLOv9 incrementally
python train_yolov9.py --epochs 10

# 2. Export best weights to TFLite
python export.py --model runs/detect/train/weights/best.pt --target assets/models/puff_detection.tflite --int8
```

---

## 👥 Project Team & Acknowledgments

**Institution:** Mangalore Institute of Technology & Engineering (MITE), Moodabidri  
**Department:** Computer Science & Engineering  
**Project Guide:** Dr. Rejeesh Rayaroth  

### Team Members:
- **Abdullah Kola**
- **Adnan Irfan Rahiman**
- **Ayush C. Umeshan**
- **Eashan Y. Poojary**

*Submitted as part of the academic curriculum for the award of Bachelor of Engineering (B.E.) in Computer Science & Engineering.*
