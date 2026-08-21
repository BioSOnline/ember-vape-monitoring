import argparse
import shutil
from pathlib import Path

from ultralytics import YOLO

ROOT = Path(__file__).resolve().parent
DEFAULT_MODEL_PATH = ROOT / 'runs' / 'detect' / 'train' / 'weights' / 'best.pt'
DEFAULT_TARGET_PATH = ROOT / 'assets' / 'models' / 'puff_detection.tflite'


def export_model(model_path: str | Path = DEFAULT_MODEL_PATH, target_path: str | Path = DEFAULT_TARGET_PATH, imgsz: int = 640, export_format: str = 'tflite', int8: bool = False) -> Path:
    source_path = Path(model_path).expanduser().resolve()
    if not source_path.exists():
        raise FileNotFoundError(f'Model weights not found: {source_path}')

    destination_path = Path(target_path).expanduser().resolve()
    destination_path.parent.mkdir(parents=True, exist_ok=True)

    print(f'Loading {source_path}...')
    model = YOLO(str(source_path))

    exported_file = None
    try:
        print(f'Exporting model to {export_format.upper()}...')
        export_path = model.export(format=export_format, imgsz=imgsz)
        if isinstance(export_path, (list, tuple)):
            export_path = export_path[0]
        exported_file = Path(export_path).expanduser().resolve()
    except Exception as e:
        print(f'Standard {export_format} export failed ({e}). Falling back to ONNX -> onnx2tf converter...')
        onnx_path = model.export(format='onnx', imgsz=imgsz)
        if isinstance(onnx_path, (list, tuple)):
            onnx_path = onnx_path[0]
        
        out_dir = source_path.parent / 'onnx2tf_out'
        import subprocess
        subprocess.run(['onnx2tf', '-i', str(onnx_path), '-o', str(out_dir)], check=True)
        
        tflite_candidate = out_dir / 'best_float32.tflite'
        if not tflite_candidate.exists():
            # Check for any .tflite in output directory
            tflites = list(out_dir.glob('*.tflite'))
            if tflites:
                tflite_candidate = tflites[0]
        
        exported_file = tflite_candidate.resolve()

    print(f'Model exported to {exported_file}')

    if not exported_file or not exported_file.exists():
        raise FileNotFoundError(f'Export failed, could not find exported file: {exported_file}')

    if exported_file != destination_path:
        print(f'Copying {exported_file} to {destination_path}')
        shutil.copy2(exported_file, destination_path)
    else:
        print(f'Export already written to {destination_path}')

    print('Done!')
    return destination_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Export a YOLO model to TFLite and copy it into Flutter assets.')
    parser.add_argument('--model', default=str(DEFAULT_MODEL_PATH), help='Path to the trained .pt weights file')
    parser.add_argument('--target', default=str(DEFAULT_TARGET_PATH), help='Path to write the exported .tflite asset')
    parser.add_argument('--imgsz', type=int, default=640, help='Export image size')
    parser.add_argument('--format', default='tflite', help='Export format passed to Ultralytics')
    parser.add_argument('--int8', dest='int8', action='store_true', help='Enable INT8 export')
    parser.add_argument('--no-int8', dest='int8', action='store_false', help='Disable INT8 export')
    parser.set_defaults(int8=True)
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    export_model(
        model_path=args.model,
        target_path=args.target,
        imgsz=args.imgsz,
        export_format=args.format,
        int8=args.int8,
    )
