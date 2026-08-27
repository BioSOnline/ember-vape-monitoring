import os
import sys
import time
import requests
import zipfile

DOWNLOAD_URL = 'https://www.kaggle.com/api/v1/datasets/download/izzulhaqmahardika/cigarette-vape-yolo-dataset'
TARGET_DIR = os.path.abspath('datasets')
ZIP_FILE = os.path.join(TARGET_DIR, 'cigarette_vape_yolo.zip')
EXTRACT_DIR = os.path.join(TARGET_DIR, 'cigarette_vape')

def download_file():
    os.makedirs(TARGET_DIR, exist_ok=True)
    print("=" * 65)
    print("EMBER Dataset Downloader: 11,384 Vape & Cigarette Detection Images")
    print("=" * 65)
    
    session = requests.Session()
    print("Resolving download endpoint...")
    r = session.get(DOWNLOAD_URL, allow_redirects=False, timeout=15)
    if r.status_code not in (301, 302):
        print(f"Error: expected redirect from Kaggle, got status {r.status_code}")
        sys.exit(1)
        
    gcs_url = r.headers.get('Location')
    print("Connecting to high-speed GCS storage...")
    
    # Check existing file size for resume if applicable
    existing_bytes = 0
    headers = {}
    if os.path.exists(ZIP_FILE):
        existing_bytes = os.path.getsize(ZIP_FILE)
        if existing_bytes > 0:
            headers['Range'] = f'bytes={existing_bytes}-'
            print(f"Resuming download from byte {existing_bytes} ({existing_bytes / (1024*1024):.1f} MB)...")
            
    resp = session.get(gcs_url, headers=headers, stream=True, timeout=30)
    
    if resp.status_code == 416: # Range not satisfiable (already fully downloaded)
        print("Archive already fully downloaded.")
    elif resp.status_code in (200, 206):
        total_length = resp.headers.get('content-length')
        total_bytes = (int(total_length) + existing_bytes) if total_length else None
        
        mode = 'ab' if resp.status_code == 206 else 'wb'
        if mode == 'wb':
            existing_bytes = 0
            
        print(f"Total archive size: {total_bytes / (1024*1024):.1f} MB" if total_bytes else "Total size unknown")
        
        downloaded = existing_bytes
        start_time = time.time()
        last_print = 0
        
        with open(ZIP_FILE, mode) as f:
            for chunk in resp.iter_content(chunk_size=1024 * 1024): # 1MB chunks
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    
                    now = time.time()
                    if now - last_print > 1.0 or downloaded == total_bytes:
                        elapsed = max(now - start_time, 0.001)
                        speed = (downloaded - existing_bytes) / elapsed / (1024 * 1024)
                        percent = (downloaded / total_bytes * 100) if total_bytes else 0
                        eta = (total_bytes - downloaded) / (speed * 1024 * 1024) if total_bytes and speed > 0 else 0
                        sys.stdout.write(
                            f"\rProgress: {percent:5.1f}% | {downloaded / (1024*1024):.1f}/{total_bytes/(1024*1024):.1f} MB | {speed:5.2f} MB/s | ETA: {int(eta)}s  "
                        )
                        sys.stdout.flush()
                        last_print = now
        print("\nDownload complete!")
    else:
        print(f"Unexpected HTTP status {resp.status_code}")
        sys.exit(1)

def extract_archive():
    print("\nExtracting archive into:", EXTRACT_DIR)
    os.makedirs(EXTRACT_DIR, exist_ok=True)
    
    with zipfile.ZipFile(ZIP_FILE, 'r') as zf:
        members = zf.namelist()
        total_files = len(members)
        print(f"Total items in zip: {total_files}")
        
        last_print = time.time()
        for idx, member in enumerate(members, start=1):
            zf.extract(member, EXTRACT_DIR)
            now = time.time()
            if now - last_print > 1.5 or idx == total_files:
                sys.stdout.write(f"\rExtracting: {idx}/{total_files} files ({(idx/total_files)*100:.1f}%)   ")
                sys.stdout.flush()
                last_print = now
                
    print(f"\nExtraction complete! Files located at: {EXTRACT_DIR}")

if __name__ == '__main__':
    download_file()
    extract_archive()
