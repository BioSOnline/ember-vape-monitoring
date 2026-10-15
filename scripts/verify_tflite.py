import os
import glob
import cv2
import numpy as np
import tensorflow as tf
from ultralytics import YOLO

def letterbox(im, new_shape=(640, 640), color=(114, 114, 114)):
    shape = im.shape[:2] # [height, width]
    if isinstance(new_shape, int):
        new_shape = (new_shape, new_shape)

    # Scale ratio (new / old)
    r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])

    # Compute padding
    new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
    dw, dh = new_shape[1] - new_unpad[0], new_shape[0] - new_unpad[1]  # wh padding
    dw /= 2  # divide padding into 2 sides
    dh /= 2

    if shape[::-1] != new_unpad:  # resize
        im = cv2.resize(im, new_unpad, interpolation=cv2.INTER_LINEAR)
    top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
    left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
    im = cv2.copyMakeBorder(im, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
    return im, r, (dw, dh)

def main():
    pt_model_path = 'runs/detect/train/weights/best.pt'
    tflite_model_path = 'assets/models/puff_detection.tflite'
    
    print(f"Loading PT model: {pt_model_path}")
    pt_model = YOLO(pt_model_path)

    print(f"Loading TFLite model: {tflite_model_path}")
    interpreter = tf.lite.Interpreter(model_path=tflite_model_path)
    interpreter.allocate_tensors()
    in_det = interpreter.get_input_details()[0]
    out_det = interpreter.get_output_details()[0]
    print(f"TFLite Input: {in_det['shape']}, {in_det['dtype']}")
    print(f"TFLite Output: {out_det['shape']}, {out_det['dtype']}")

    val_images = glob.glob('assets/newds/valid/images/*.jpg')[:10]
    print(f"Testing on {len(val_images)} validation images...\n")

    for img_path in val_images:
        filename = os.path.basename(img_path)
        img_bgr = cv2.imread(img_path)
        if img_bgr is None:
            continue
        h0, w0 = img_bgr.shape[:2]

        # 1. Ultralytics PyTorch prediction
        pt_res = pt_model(img_path, verbose=False)[0]
        pt_boxes = pt_res.boxes
        print(f"=== Image: {filename} ({w0}x{h0}) ===")
        print(f"PT detected {len(pt_boxes)} boxes:")
        for b in pt_boxes:
            cls_id = int(b.cls[0].item())
            cls_name = pt_model.names[cls_id]
            conf = float(b.conf[0].item())
            xyxy = b.xyxy[0].tolist()
            print(f"  [PT] {cls_name} ({cls_id}): conf={conf:.3f}, box={xyxy}")

        # 2. TFLite prediction
        img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        input_img, r, (dw, dh) = letterbox(img_rgb, new_shape=(640, 640))
        input_data = input_img.astype(np.float32) / 255.0
        input_data = np.expand_dims(input_data, axis=0) # [1, 640, 640, 3]

        interpreter.set_tensor(in_det['index'], input_data)
        interpreter.invoke()
        output = interpreter.get_tensor(out_det['index']) # e.g. [1, 6, 8400]

        # Check raw output stats
        # YOLOv9 output: [1, 6, 8400] where 6 is [x, y, w, h, class0_conf, class1_conf]
        if output.shape[1] == 6:
            # [1, 6, 8400] -> transpose to [8400, 6]
            preds = output[0].T
        else:
            preds = output[0] # if [8400, 6]

        print(f"  [TFLite] Raw output shape: {output.shape}, transposed to {preds.shape}")
        print(f"  [TFLite] Min/Max values:")
        print(f"    x: [{preds[:, 0].min():.2f}, {preds[:, 0].max():.2f}]")
        print(f"    y: [{preds[:, 1].min():.2f}, {preds[:, 1].max():.2f}]")
        print(f"    w: [{preds[:, 2].min():.2f}, {preds[:, 2].max():.2f}]")
        print(f"    h: [{preds[:, 3].min():.2f}, {preds[:, 3].max():.2f}]")
        print(f"    cls0: [{preds[:, 4].min():.4f}, {preds[:, 4].max():.4f}]")
        print(f"    cls1: [{preds[:, 5].min():.4f}, {preds[:, 5].max():.4f}]")

        # Parse boxes with conf >= 0.25
        tflite_detections = []
        for i in range(preds.shape[0]):
            c0 = preds[i, 4]
            c1 = preds[i, 5]
            max_c = max(c0, c1)
            if max_c >= 0.25:
                best_cls = 0 if c0 >= c1 else 1
                cx, cy, w, h = preds[i, :4]
                # Convert cx, cy, w, h to xyxy in original image coords
                # Check whether cx, cy, w, h are in 640 pixel coordinates or 0-1
                # If cx > 1.0, they are in 640 pixel coords!
                x1 = cx - w / 2.0
                y1 = cy - h / 2.0
                x2 = cx + w / 2.0
                y2 = cy + h / 2.0

                # Un-letterbox
                orig_x1 = (x1 - dw) / r
                orig_y1 = (y1 - dh) / r
                orig_x2 = (x2 - dw) / r
                orig_y2 = (y2 - dh) / r
                tflite_detections.append((best_cls, max_c, [orig_x1, orig_y1, orig_x2, orig_y2]))

        print(f"  [TFLite] Candidate raw boxes >= 0.25 (before NMS): {len(tflite_detections)}")
        # Simple NMS
        if tflite_detections:
            boxes = np.array([d[2] for d in tflite_detections])
            scores = np.array([d[1] for d in tflite_detections])
            classes = np.array([d[0] for d in tflite_detections])
            indices = cv2.dnn.NMSBoxes(
                bboxes=[[int(b[0]), int(b[1]), int(b[2]-b[0]), int(b[3]-b[1])] for b in boxes],
                scores=scores.tolist(),
                score_threshold=0.25,
                nms_threshold=0.45
            )
            print(f"  [TFLite] Filtered by NMS: {len(indices)} boxes:")
            for idx in indices:
                i = int(idx) if np.isscalar(idx) else int(idx[0])
                cls_name = pt_model.names[classes[i]]
                print(f"    [TFLite] {cls_name} ({classes[i]}): conf={scores[i]:.3f}, box={boxes[i].tolist()}")
        print()

if __name__ == '__main__':
    main()
