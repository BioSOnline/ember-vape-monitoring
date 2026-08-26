import os
import json
import torch
from datetime import datetime
from ultralytics import YOLO
from export import export_model

import argparse

PROGRESS_FILE = os.path.abspath('training_progress.json')


def get_increment_epochs(current_total):
    parser = argparse.ArgumentParser(description='Incremental YOLOv9 Training for EMBER')
    parser.add_argument('--epochs', type=int, default=None, help='Number of epochs to train in this batch')
    args, _ = parser.parse_known_args()
    if args.epochs is not None:
        return args.epochs
    # 5 epochs for this run (from 5 -> 10 total), then 10 epochs for subsequent runs
    return 5 if current_total < 10 else 10


def load_training_progress():
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            pass

    # Default if no progress file exists yet:
    # Check if there is an existing results.csv to infer initial epochs
    initial_epochs = 0
    results_csv = 'runs/detect/train/results.csv'
    if os.path.exists(results_csv):
        try:
            with open(results_csv, 'r') as f:
                lines = [line.strip() for line in f.readlines() if line.strip()]
                # subtract 1 for header line
                if len(lines) > 1:
                    initial_epochs = len(lines) - 1
        except Exception:
            pass

    return {
        'total_cumulative_epochs': initial_epochs,
        'history': []
    }


def save_training_progress(total_epochs, run_info):
    progress = load_training_progress()
    progress['total_cumulative_epochs'] = total_epochs
    progress['history'].append(run_info)
    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f, indent=2)


if __name__ == '__main__':
    progress = load_training_progress()
    current_total_epochs = progress.get('total_cumulative_epochs', 0)
    increment_epochs = get_increment_epochs(current_total_epochs)
    target_total_epochs = current_total_epochs + increment_epochs

    print("=" * 60)
    print("EMBER YOLOv9 Incremental Training")
    print(f"Previously trained cumulative epochs: {current_total_epochs}")
    print(f"Training for +{increment_epochs} more epochs (Cumulative Target: {target_total_epochs})")
    print("=" * 60)

    # If previous best.pt exists, fine-tune on top of it, otherwise use pretrained yolov9t.pt
    best_weights = os.path.abspath('runs/detect/train/weights/best.pt')
    if os.path.exists(best_weights):
        base_model = best_weights
        print(f"Continuing training from existing weights: {base_model}")
    else:
        base_model = 'yolov9t.pt'
        print(f"Starting fresh training with base model: {base_model}")

    # Determine optimal compute device (CUDA GPU if available, else CPU)
    device = 0 if torch.cuda.is_available() else 'cpu'
    device_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'
    print(f"Compute Device: {device_name} (device={device})")

    model = YOLO(base_model)
    data_yaml_path = os.path.abspath('assets/newds/data.yaml')
    print(f"Dataset configuration: {data_yaml_path}")
    
    # Train for incremental epochs
    results = model.train(
        data=data_yaml_path,
        epochs=increment_epochs,
        imgsz=640,
        name='train',
        exist_ok=True,
        device=device,
        save=True,
        plots=True,
        cos_lr=True,
    )

    # Record the newly completed progress
    run_record = {
        'timestamp': datetime.now().isoformat(),
        'previous_total_epochs': current_total_epochs,
        'added_epochs': increment_epochs,
        'new_total_epochs': target_total_epochs,
        'weights_file': best_weights,
    }
    save_training_progress(target_total_epochs, run_record)

    next_increment = 10
    print("\n" + "=" * 60)
    print(f"✅ Incremental training complete! Total cumulative epochs: {target_total_epochs}")
    print(f"Progress recorded in: {PROGRESS_FILE}")
    print(f"Next run will train +{next_increment} epochs (Target: {target_total_epochs + next_increment})")
    print("=" * 60)

    # Export trained model from best weights to Flutter asset
    print(f"\nExporting trained model from {best_weights} to Flutter asset...")
    export_path = export_model(model_path=best_weights)
    print(f"Model exported to {export_path}")
    print(f"Batch (+{increment_epochs} epochs) training and export complete!")
