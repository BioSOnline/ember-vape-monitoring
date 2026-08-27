import os
import shutil
import glob
from collections import Counter

SOURCE_ROOT = os.path.abspath('datasets/cigarette_vape/yolo-dataset')
TARGET_ROOT = os.path.abspath('assets/newds')

# Incoming dataset mapping:
# 0 (cigarette) -> 1 (Cigarette in EMBER)
# 1 (vape)      -> 0 (Vape in EMBER)
CLASS_REMAP = {
    '0': '1', # cigarette -> Cigarette
    '1': '0', # vape -> Vape
}

def merge_datasets():
    print("=" * 65)
    print("EMBER Dataset Harmonization & Merge Pipeline")
    print("=" * 65)

    if not os.path.exists(SOURCE_ROOT):
        raise FileNotFoundError(f"Source dataset not found at {SOURCE_ROOT}. Please ensure download has completed.")

    stats = {
        'train': {'images_added': 0, 'boxes': Counter(), 'negatives': 0},
        'valid': {'images_added': 0, 'boxes': Counter(), 'negatives': 0}
    }

    for split in ['train', 'valid']:
        src_img_dir = os.path.join(SOURCE_ROOT, split, 'images')
        src_lbl_dir = os.path.join(SOURCE_ROOT, split, 'labels')
        
        tgt_img_dir = os.path.join(TARGET_ROOT, split, 'images')
        tgt_lbl_dir = os.path.join(TARGET_ROOT, split, 'labels')
        
        os.makedirs(tgt_img_dir, exist_ok=True)
        os.makedirs(tgt_lbl_dir, exist_ok=True)

        if not os.path.exists(src_img_dir):
            continue

        for img_path in glob.glob(os.path.join(src_img_dir, '*')):
            if not os.path.isfile(img_path):
                continue

            base_name = os.path.basename(img_path)
            stem, ext = os.path.splitext(base_name)
            
            # Prefix to avoid collision with existing assets
            new_filename = f"cv_{base_name}"
            new_stem = f"cv_{stem}"
            
            dest_img_path = os.path.join(tgt_img_dir, new_filename)
            dest_lbl_path = os.path.join(tgt_lbl_dir, f"{new_stem}.txt")

            # Copy image (skip if already present)
            if not os.path.exists(dest_img_path):
                shutil.copy2(img_path, dest_img_path)

            # Process and remap label
            src_lbl_path = os.path.join(src_lbl_dir, f"{stem}.txt")
            new_lines = []
            
            if os.path.exists(src_lbl_path):
                with open(src_lbl_path, 'r', encoding='utf-8') as f:
                    lines = [l.strip() for l in f if l.strip()]
                for line in lines:
                    parts = line.split()
                    if not parts:
                        continue
                    orig_cls = parts[0]
                    new_cls = None
                    try:
                        cls_idx = int(float(orig_cls))
                        if cls_idx == 0: # cigarette -> 1 (Cigarette)
                            new_cls = '1'
                        elif cls_idx == 1: # vape -> 0 (Vape)
                            new_cls = '0'
                    except Exception:
                        pass
                        
                    if new_cls is not None:
                        new_lines.append(f"{new_cls} {' '.join(parts[1:])}")
                        stats[split]['boxes'][new_cls] += 1
                    else:
                        print(f"Warning: Unexpected class {orig_cls} in {src_lbl_path}")

            with open(dest_lbl_path, 'w', encoding='utf-8') as f:
                for nl in new_lines:
                    lf = nl + '\n'
                    f.write(lf)

            stats[split]['images_added'] += 1
            if len(new_lines) == 0:
                stats[split]['negatives'] += 1

    print("\nMerge Completed Successfully!")
    print(f"Train images added: {stats['train']['images_added']}")
    print(f"  Vape annotations (0):      {stats['train']['boxes']['0']}")
    print(f"  Cigarette annotations (1): {stats['train']['boxes']['1']}")
    print(f"  Background negatives:      {stats['train']['negatives']}")
    print(f"Valid images added: {stats['valid']['images_added']}")
    print(f"  Vape annotations (0):      {stats['valid']['boxes']['0']}")
    print(f"  Cigarette annotations (1): {stats['valid']['boxes']['1']}")
    print(f"  Background negatives:      {stats['valid']['negatives']}")

    # Invalidate old YOLO label caches so Ultralytics rescans all labels
    for split in ['train', 'valid']:
        for cache_file in glob.glob(os.path.join(TARGET_ROOT, split, '*.cache')) + glob.glob(os.path.join(TARGET_ROOT, split, 'labels', '*.cache')):
            try:
                os.remove(cache_file)
                print(f"Cleared old cache: {cache_file}")
            except Exception:
                pass

    total_train = len(glob.glob(os.path.join(TARGET_ROOT, 'train/images/*')))
    total_valid = len(glob.glob(os.path.join(TARGET_ROOT, 'valid/images/*')))
    print("-" * 65)
    print(f"TOTAL DATASET NOW IN {TARGET_ROOT}:")
    print(f"  Train images: {total_train}")
    print(f"  Valid images: {total_valid}")
    print(f"  Total images: {total_train + total_valid}")
    print("=" * 65)

if __name__ == '__main__':
    merge_datasets()
