import os
import json
import shutil
import yaml
import torch
from datetime import datetime
from ultralytics import YOLO
from export import export_model
import argparse

PROGRESS_FILE = os.path.abspath('training_progress.json')
DATA_YAML = os.path.abspath('assets/newds/data.yaml')

def get_cli_args():
    parser = argparse.ArgumentParser(description='EMBER YOLOv9 Training Pipeline')
    parser.add_argument('--epochs', type=int, default=None, help='Number of epochs to train in this batch')
    parser.add_argument('--fresh', action='store_true', help='Force start fresh training from base yolov9t.pt')
    parser.add_argument('--batch', type=int, default=16, help='Batch size for training')
    parser.add_argument('--imgsz', type=int, default=640, help='Image resolution')
    parser.add_argument('--lr0', type=float, default=None, help='Initial learning rate (defaults to 0.001 for fine-tuning, 0.01 for fresh)')
    parser.add_argument('--device', type=str, default=None, help='Device to train on, e.g. "cpu" or "0" (defaults to GPU 0 if available)')
    parser.add_argument('--threads', type=int, default=None, help='PyTorch CPU threads limit (default 4 on CPU for quiet operation)')
    parser.add_argument('--workers', type=int, default=None, help='Dataloader workers (default 2 on CPU, 8 on GPU)')
    args, _ = parser.parse_known_args()
    return args

def load_training_progress():
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            pass

    return {
        'total_cumulative_epochs': 0,
        'history': []
    }

def save_training_progress(total_epochs, run_info):
    progress = load_training_progress()
    progress['total_cumulative_epochs'] = total_epochs
    progress['history'].append(run_info)
    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f, indent=2)

if __name__ == '__main__':
    args = get_cli_args()
    
    # Load dataset config
    with open(DATA_YAML, 'r') as f:
        data_cfg = yaml.safe_load(f)
    num_classes = data_cfg.get('nc', 2)
    class_names = data_cfg.get('names', ['Vape', 'Cigarette'])

    best_weights = os.path.abspath('runs/detect/train/weights/best.pt')
    
    # Check if we need a fresh start (flag or class count mismatch)
    need_fresh = args.fresh
    if os.path.exists(best_weights) and not need_fresh:
        try:
            temp_model = YOLO(best_weights)
            weights_nc = len(temp_model.names)
            if weights_nc != num_classes:
                print(f"⚠️ Model weights class count ({weights_nc}) != dataset class count ({num_classes}).")
                print("Automatically initiating fresh training from base yolov9t.pt...")
                need_fresh = True
        except Exception:
            need_fresh = True

    if need_fresh:
        # Archive previous 4-class weights/runs if present
        train_dir = os.path.abspath('runs/detect/train')
        if os.path.exists(train_dir):
            archive_dir = os.path.abspath('runs/detect/train_legacy_4class')
            if not os.path.exists(archive_dir):
                print(f"Archiving previous training run to {archive_dir}...")
                shutil.copytree(train_dir, archive_dir)
            shutil.rmtree(train_dir)
        
        # Reset progress file
        with open(PROGRESS_FILE, 'w') as f:
            json.dump({
                'model_version': '2-class-consolidated',
                'classes': class_names,
                'total_cumulative_epochs': 0,
                'history': []
            }, f, indent=2)
        
        base_model = 'yolov9t.pt'
        current_total_epochs = 0
        epochs_to_train = args.epochs if args.epochs is not None else 20
    else:
        progress = load_training_progress()
        current_total_epochs = progress.get('total_cumulative_epochs', 0)
        epochs_to_train = args.epochs if args.epochs is not None else 10
        base_model = best_weights if os.path.exists(best_weights) else 'yolov9t.pt'

    target_total_epochs = current_total_epochs + epochs_to_train

    print("=" * 65)
    print("EMBER YOLOv9 Training Pipeline")
    print(f"Target Classes: {class_names} (nc={num_classes})")
    print(f"Base Weights:   {base_model}")
    print(f"Prior Epochs:   {current_total_epochs}")
    print(f"Target Epochs:  +{epochs_to_train} (Total: {target_total_epochs})")
    print("=" * 65)

    if args.device is not None:
        device = args.device
        if str(device).lower() == 'cpu':
            device_name = 'CPU'
        elif str(device).isdigit() and torch.cuda.is_available():
            device_name = torch.cuda.get_device_name(int(device))
        else:
            device_name = str(device)
    else:
        device = 0 if torch.cuda.is_available() else 'cpu'
        device_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'
    print(f"Compute Device: {device_name} (device={device})")

    is_cpu = str(device).lower() == 'cpu'
    if is_cpu:
        num_threads = args.threads if args.threads is not None else 4
        torch.set_num_threads(num_threads)
        print(f"CPU Mode: Limiting PyTorch threads to {num_threads} to keep thermals & fan noise low.")

    model = YOLO(base_model)

    results = model.train(
        data=DATA_YAML,
        epochs=epochs_to_train,
        imgsz=args.imgsz,
        batch=args.batch,
        name='train',
        exist_ok=True,
        device=device,
        save=True,
        plots=True,
        cos_lr=True,
    )

    run_record = {
        'timestamp': datetime.now().isoformat(),
        'previous_total_epochs': current_total_epochs,
        'added_epochs': epochs_to_train,
        'new_total_epochs': target_total_epochs,
        'weights_file': best_weights,
        'classes': class_names,
    }
    save_training_progress(target_total_epochs, run_record)

    print("\n" + "=" * 65)
    print(f"✅ Training run complete! Total cumulative epochs: {target_total_epochs}")
    print("=" * 65)

    # Export trained model to Flutter asset
    print(f"\nExporting newly trained model from {best_weights} to Flutter assets...")
    export_path = export_model(model_path=best_weights)
    print(f"Model exported to {export_path}")
