#!/bin/bash
# Export as FP32 (full precision, no quantization) - best accuracy for all classes
python3 -c "
from ultralytics import YOLO
import shutil, os

model = YOLO('/mnt/c/Users/ADNAN/Desktop/EMBER/runs/detect/train/weights/best.pt')
print('Exporting to FP32 TFLite (full precision, no quantization)...')
export_path = model.export(format='tflite', quantize=32)
print(f'Exported to: {export_path}')

target = '/mnt/c/Users/ADNAN/Desktop/EMBER/assets/models/puff_detection.tflite'
shutil.copy2(export_path, target)
print(f'Copied to {target}')
print('Done!')
"
