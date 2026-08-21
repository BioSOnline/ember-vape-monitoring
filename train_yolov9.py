import os
from ultralytics import YOLO
from export import export_model
if __name__ == '__main__':
    # If previous best.pt exists, fine-tune on top of it, otherwise use pretrained yolov9t.pt
    base_model = 'yolov9t.pt'
    if os.path.exists('runs/detect/train/weights/best.pt'):
        base_model = 'runs/detect/train/weights/best.pt'
        print(f"Continuing training from existing weights: {base_model}")
    else:
        print(f"Starting fresh training with base model: {base_model}")

    model = YOLO(base_model)
    data_yaml_path = os.path.abspath('assets/newds/data.yaml')
    print(f"Starting training for 5 epochs on {data_yaml_path}...")
    
    # Run training in batches of 5 epochs
    results = model.train(
        data=data_yaml_path,
        epochs=5,
        imgsz=640,
        name='train',
        exist_ok=True
    )
    
    best_weights = 'runs/detect/train/weights/best.pt'
    print(f"Exporting trained model from {best_weights} to Flutter asset...")
    export_path = export_model(model_path=best_weights)
    print(f"Model exported to {export_path}")
    print("5-epoch training batch and export complete!")
