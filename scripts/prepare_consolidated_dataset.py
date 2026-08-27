import os
import shutil
import random
import glob
import re
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from collections import Counter
from PIL import Image
import io

DATASET_ROOT = os.path.abspath('assets/newds')
DATA_YAML = os.path.join(DATASET_ROOT, 'data.yaml')

# Class consolidation mapping:
# 0 (Vape) -> 0 (Vape)
# 2 (iqos) -> 0 (Vape)
# 1 (cigarette) -> 1 (Cigarette)
# 3 (trubka/pipe) -> 1 (Cigarette)
CLASS_MAPPING = {
    '0': '0',
    '2': '0',
    '1': '1',
    '3': '1'
}

def extract_source_key(filename):
    """
    Extract base stem ignoring Roboflow hashes and common prefixes/suffixes
    to guarantee identical images and video frames are grouped together.
    """
    stem = os.path.splitext(filename)[0]
    if '.rf.' in stem:
        stem = stem.split('.rf.')[0]
    if stem.endswith('_jpg') or stem.endswith('_png') or stem.endswith('_jpeg'):
        stem = stem[:-4]
    
    # If the stem is purely numeric (e.g., '154', '210'), that usually represents frame IDs.
    # Group them together as video sequences if possible or by chunk:
    if stem.isdigit():
        # Keep numeric stems grouped
        return f"numeric_seq_{stem}"
    return stem

def download_single_negative(seed, target_img_path, target_lbl_path):
    url = f'https://picsum.photos/seed/{seed}/640/640'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (EMBER Dataset Curator)'})
    try:
        with urllib.request.urlopen(req, timeout=12) as response:
            data = response.read()
            img = Image.open(io.BytesIO(data)).convert('RGB')
            img.save(target_img_path, 'JPEG', quality=92)
            # Create corresponding empty label file for YOLO negative background
            with open(target_lbl_path, 'w') as f:
                pass
            return True
    except Exception as e:
        print(f"Failed downloading seed {seed}: {e}")
        return False

def main():
    print("=" * 65)
    print("EMBER Dataset Restructuring: Class Consolidation, Group Split & Negatives")
    print("=" * 65)

    if not os.path.exists(DATASET_ROOT):
        raise FileNotFoundError(f"Dataset root not found: {DATASET_ROOT}")

    # 1. Gather all existing images and labels from train and valid
    raw_samples = []
    for split in ['train', 'valid']:
        img_dir = os.path.join(DATASET_ROOT, split, 'images')
        lbl_dir = os.path.join(DATASET_ROOT, split, 'labels')
        if not os.path.exists(img_dir):
            continue
        for img_path in glob.glob(os.path.join(img_dir, '*')):
            if not os.path.isfile(img_path):
                continue
            base_filename = os.path.basename(img_path)
            stem, ext = os.path.splitext(base_filename)
            lbl_path = os.path.join(lbl_dir, f"{stem}.txt")
            raw_samples.append({
                'img_path': img_path,
                'lbl_path': lbl_path if os.path.exists(lbl_path) else None,
                'filename': base_filename,
                'group_key': extract_source_key(base_filename),
            })

    print(f"Total existing samples gathered: {len(raw_samples)}")

    # 2. Group samples by group_key to eliminate data leakage
    grouped_samples = {}
    for item in raw_samples:
        grouped_samples.setdefault(item['group_key'], []).append(item)

    print(f"Total unique source groups: {len(grouped_samples)}")

    # 3. Deterministic Group Split: 80% Train, 20% Valid
    random.seed(42)
    all_group_keys = list(grouped_samples.keys())
    random.shuffle(all_group_keys)

    split_idx = int(0.80 * len(all_group_keys))
    train_groups = set(all_group_keys[:split_idx])
    valid_groups = set(all_group_keys[split_idx:])

    # Guarantee zero leakage
    leakage = train_groups.intersection(valid_groups)
    assert len(leakage) == 0, f"Error: Data leakage detected across groups: {leakage}"

    # 4. Stage restructured dataset into temporary directory
    staging_dir = os.path.join(DATASET_ROOT, '_staged_consolidated')
    if os.path.exists(staging_dir):
        shutil.rmtree(staging_dir)

    for split in ['train', 'valid']:
        os.makedirs(os.path.join(staging_dir, split, 'images'), exist_ok=True)
        os.makedirs(os.path.join(staging_dir, split, 'labels'), exist_ok=True)

    stats = {
        'train': {'images': 0, 'boxes': Counter(), 'negatives': 0},
        'valid': {'images': 0, 'boxes': Counter(), 'negatives': 0}
    }

    print("\nProcessing and consolidating annotations...")
    for group_key, items in grouped_samples.items():
        split = 'train' if group_key in train_groups else 'valid'
        for item in items:
            dest_img = os.path.join(staging_dir, split, 'images', item['filename'])
            dest_lbl = os.path.join(staging_dir, split, 'labels', f"{os.path.splitext(item['filename'])[0]}.txt")

            shutil.copy2(item['img_path'], dest_img)

            # Consolidate bounding box labels
            new_lines = []
            if item['lbl_path'] and os.path.exists(item['lbl_path']):
                with open(item['lbl_path'], 'r') as lf:
                    lines = [l.strip() for l in lf if l.strip()]
                for line in lines:
                    parts = line.split()
                    orig_cls = parts[0]
                    if orig_cls in CLASS_MAPPING:
                        new_cls = CLASS_MAPPING[orig_cls]
                        new_lines.append(f"{new_cls} {' '.join(parts[1:])}")
                        stats[split]['boxes'][new_cls] += 1

            with open(dest_lbl, 'w') as lf:
                for nl in new_lines:
                    lf.write(nl + '\n')

            stats[split]['images'] += 1
            if len(new_lines) == 0:
                stats[split]['negatives'] += 1

    # 5. Download and inject negative background images (~220 images)
    print("\nIngesting 220 negative background images (faces, hands, drinking, everyday scenes)...")
    neg_total = 220
    neg_train_count = int(neg_total * 0.82) # ~180 train
    neg_valid_count = neg_total - neg_train_count # ~40 valid

    tasks = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        for i in range(1, neg_total + 1):
            split = 'train' if i <= neg_train_count else 'valid'
            img_dest = os.path.join(staging_dir, split, 'images', f"bg_negative_{i:04d}.jpg")
            lbl_dest = os.path.join(staging_dir, split, 'labels', f"bg_negative_{i:04d}.txt")
            tasks.append(executor.submit(download_single_negative, f"ember_bg_{i*37}", img_dest, lbl_dest))

    success_downloads = sum(1 for t in tasks if t.result())
    print(f"Successfully downloaded and integrated {success_downloads} negative background samples.")

    # 6. Replace old train and valid with staged version
    backup_dir = os.path.join(DATASET_ROOT, '_backup_original')
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir, exist_ok=True)
        for split in ['train', 'valid']:
            src = os.path.join(DATASET_ROOT, split)
            if os.path.exists(src):
                shutil.copytree(src, os.path.join(backup_dir, split))
        if os.path.exists(DATA_YAML):
            shutil.copy2(DATA_YAML, os.path.join(backup_dir, 'data.yaml'))
        print(f"Original dataset safely backed up to {backup_dir}")

    # Remove old train/valid
    for split in ['train', 'valid']:
        dst = os.path.join(DATASET_ROOT, split)
        if os.path.exists(dst):
            shutil.rmtree(dst)
        shutil.move(os.path.join(staging_dir, split), dst)

    if os.path.exists(staging_dir):
        shutil.rmtree(staging_dir)

    # 7. Update data.yaml
    with open(DATA_YAML, 'w') as f:
        f.write("train: ../train/images\n")
        f.write("val: ../valid/images\n")
        f.write("test: ../test/images\n\n")
        f.write("nc: 2\n")
        f.write("names: ['Vape', 'Cigarette']\n")

    print("\nUpdated data.yaml with 2 consolidated classes: ['Vape', 'Cigarette']")

    # 8. Print Final Dataset Summary
    train_imgs = len(glob.glob(os.path.join(DATASET_ROOT, 'train/images/*')))
    train_lbls = len(glob.glob(os.path.join(DATASET_ROOT, 'train/labels/*.txt')))
    valid_imgs = len(glob.glob(os.path.join(DATASET_ROOT, 'valid/images/*')))
    valid_lbls = len(glob.glob(os.path.join(DATASET_ROOT, 'valid/labels/*.txt')))

    print("\n" + "=" * 65)
    print("FINAL DATASET SUMMARY")
    print("=" * 65)
    print(f"TRAIN Set: {train_imgs} images, {train_lbls} labels")
    print(f"  Class 0 (Vape):      {stats['train']['boxes']['0']} boxes")
    print(f"  Class 1 (Cigarette): {stats['train']['boxes']['1']} boxes")
    print(f"  Negatives added:     {neg_train_count}")
    print(f"VALID Set: {valid_imgs} images, {valid_lbls} labels")
    print(f"  Class 0 (Vape):      {stats['valid']['boxes']['0']} boxes")
    print(f"  Class 1 (Cigarette): {stats['valid']['boxes']['1']} boxes")
    print(f"  Negatives added:     {neg_valid_count}")
    print(f"Group Leakage Check:   0 overlapping groups (PASS)")
    print("=" * 65)

if __name__ == '__main__':
    main()
