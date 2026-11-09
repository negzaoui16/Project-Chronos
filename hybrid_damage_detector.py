"""
Hybrid Damage Detector - YOLO + VLM
--------------------------------------
Combines the two tools per the routing decision:
  - Trained YOLO model handles the classes it's actually good at
    (missing_button, disassembled, broken_other, chip, crack, damaged_screen,
    dead_pixel, display_lines, keyboard_issue, missing_screw)
  - VLM classifier (damage_type_classifier.py) handles scratch/cosmetic_wear
    assessment via its own visual reasoning, plus any other low-data class
    (see class_routing.py for exactly which classes go where, and why)

IMPORTANT: the VLM check always runs, even if YOLO found zero scratch
detections - YOLO's scratch RECALL is too low (~0.2 mAP50, confirmed across
two model generations) to treat "no scratch detections" as "no scratches
present". Relying only on "ask VLM when YOLO found a scratch box" would
still miss most real scratches, since YOLO frequently doesn't detect them
at all. This is why the VLM assessment is unconditional, not a fallback
triggered only by a specific YOLO detection.

baseline_path/return_path: the full (not cropped) pickup and return
photos. These are OPTIONAL but should be supplied whenever available -
they let the VLM check whether the flagged damage is genuinely NEW or
already present in the baseline (e.g. an old scratch), rather than
trusting the crop alone. This capability already existed in
damage_type_classifier.py but was never exposed here until now.
"""

import os
from ultralytics import YOLO

from class_routing import YOLO_TRAINED_CLASSES, get_shared_category
from damage_type_classifier import classify_damage_with_consistency

DEFAULT_YOLO_CONFIDENCE_THRESHOLD = 0.4  # matches class_routing.route_detection()'s default -
                                           # keep these in sync if either changes

_model_cache = {}


def _get_yolo_model(model_path):
    if model_path not in _model_cache:
        _model_cache[model_path] = YOLO(model_path)
    return _model_cache[model_path]


def run_yolo_detection(image_path: str, model_path: str, raw_confidence: float = 0.25) -> list:
    """
    Runs the trained model and returns ALL raw detections (not yet filtered
    by trust) as a list of {class_name, confidence, bbox}. raw_confidence is
    intentionally lower than the trust threshold - see filter_trusted_detections()
    for where the real trust decision happens.
    """
    model = _get_yolo_model(model_path)
    results = model(image_path, conf=raw_confidence, verbose=False)

    detections = []
    for box in results[0].boxes:
        detections.append({
            "class_name": model.names[int(box.cls)],
            "confidence": float(box.conf),
            "bbox": tuple(round(x) for x in box.xyxy[0].tolist()),
        })
    return detections


def filter_trusted_detections(detections: list, confidence_threshold: float = DEFAULT_YOLO_CONFIDENCE_THRESHOLD) -> list:
    """
    Keeps only detections that are BOTH a class YOLO is actually good at
    AND above the trust threshold - everything else (scratch, low-data
    classes, or just low-confidence noise) is excluded here, since those
    are the VLM's job instead.
    """
    trusted = []
    for det in detections:
        if det["class_name"] in YOLO_TRAINED_CLASSES and det["confidence"] >= confidence_threshold:
            trusted.append({
                "source": "yolo",
                "fine_grained_class": det["class_name"],
                "shared_category": get_shared_category(det["class_name"]),
                "confidence": det["confidence"],
                "bbox": det["bbox"],
            })
    return trusted


def detect_damage_hybrid(image_path: str, model_path: str, item_type: str = "laptop",
                          yolo_confidence_threshold: float = DEFAULT_YOLO_CONFIDENCE_THRESHOLD,
                          vlm_change_score: float = 0.5, api_key: str = None,
                          baseline_path: str = None, return_path: str = None) -> dict:
    """
    Main entry point. Returns:
      {
        "yolo_findings": [...],       # trusted YOLO detections, mapped to shared taxonomy
        "vlm_assessment": {...},      # the VLM's independent scratch/cosmetic-wear check,
                                        # now includes is_new_damage
        "raw_yolo_detections": [...], # everything YOLO found, including untrusted/excluded
                                        # ones - kept for transparency/debugging, not used
                                        # in the final decision
      }

    vlm_change_score: Agent 1's change_score, if this is being called downstream
    of Agent 1 in the real pipeline. Defaults to 0.5 ("moderate, unknown") when
    called standalone without that context.

    baseline_path/return_path: the FULL (uncropped) pickup/return photos -
    pass these whenever available so the VLM can distinguish new damage
    from pre-existing damage, not just judge the crop in isolation.
    """
    if not os.path.isfile(model_path):
        raise FileNotFoundError(f"YOLO model not found at {model_path}")

    raw_detections = run_yolo_detection(image_path, model_path)
    trusted_findings = filter_trusted_detections(raw_detections, yolo_confidence_threshold)

    # ALWAYS run the VLM check too - see module docstring for why this is
    # unconditional rather than only triggered by a YOLO scratch detection
    vlm_result = classify_damage_with_consistency(
        crop_path=image_path, item_type=item_type, change_score=vlm_change_score, api_key=api_key,
        baseline_path=baseline_path, return_path=return_path,
    )

    return {
        "yolo_findings": trusted_findings,
        "vlm_assessment": {
            "damage_type": vlm_result.final_damage_type,
            "damage_level": vlm_result.final_damage_level,
            "confidence_agreement_ratio": vlm_result.agreement_ratio,
            "requires_human_review": vlm_result.requires_human_review,
            "is_new_damage": vlm_result.is_new_damage,
            "description": vlm_result.final_description,
        },
        "raw_yolo_detections": raw_detections,
    }
