# TFLite Model Placeholder

This directory should contain the trained YOLOv8-nano INT8 quantized TensorFlow Lite model.

## Required File
- `puff_detection.tflite` - Quantized YOLOv8 model for puff detection

## How to Generate

1. Train YOLOv8-nano on annotated smoking/vaping dataset
2. Export to TFLite with INT8 quantization
3. Copy the `.tflite` file here
4. The model will be automatically loaded by `PuffDetectionService`

## Model Specifications
- **Input:** 640×640 RGB image (normalized 0-1)
- **Output:** [1, num_detections, 6] → [x, y, w, h, confidence, class_id]
- **Classes:** 0=puff_event, 1=no_puff
- **Quantization:** INT8
- **Size:** Target < 10MB for mobile deployment

---

**Note:** The model file is excluded from version control due to size.
Add it manually after training.
