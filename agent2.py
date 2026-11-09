"""
Agent 2 - Visual Damage-Type Classification (Gradio version)
------------------------------------------------------------------
Same pattern as Agent 1's Space: Gradio Blocks, @spaces.GPU decorator
applied from the start this time (learned from Agent 1's ZeroGPU surprise -
no need to hit that issue twice).

Routes by item_type:
  - laptop -> the hybrid YOLO+VLM detector (needs laptop_damage.pt, uploaded
    directly to this Space's files)
  - everything else -> the VLM-only detector

GOOGLE_API_KEY is read from the environment, NOT taken as user input - set
it as a Repository Secret in this Space's Settings, never passed through
the UI or the API call itself. This matches how damage_type_classifier.py
already works (falls back to os.environ.get("GOOGLE_API_KEY") when no
api_key is explicitly passed) - no code change needed there, just correct
deployment configuration here.

Run locally to test: python app.py
"""

import os

import gradio as gr

from hybrid_damage_detector import detect_damage_hybrid
from vlm_only_detector import detect_damage_vlm_only

try:
    import spaces
    gpu_decorator = spaces.GPU
except ImportError:
    def gpu_decorator(func):
        return func

ITEM_TYPES = ["laptop", "tablet", "vr_headset", "lab_kit", "projector", "printer"]

# laptop_damage.pt must be uploaded directly into this Space alongside app.py
LAPTOP_MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "laptop_damage.pt")


@gpu_decorator
def process(item_type, crop_image, change_score, baseline_image, return_image):
    """
    Core logic, kept as a plain function so it's testable independently of
    Gradio's UI wiring.

    baseline_image/return_image are OPTIONAL - when provided, lets the VLM
    check whether the flagged damage is genuinely new or already present
    in the baseline (per the old-vs-new-damage feature built earlier).
    """
    if not item_type or item_type not in ITEM_TYPES:
        return {"error": f"Unknown item_type '{item_type}'. Known types: {ITEM_TYPES}"}

    if not crop_image:
        return {"error": "A crop image (the flagged region from Agent 1) is required."}

    if not os.environ.get("GOOGLE_API_KEY"):
        return {"error": "GOOGLE_API_KEY is not set on this Space - add it as a Repository Secret "
                          "in Settings, this cannot be provided through the API call itself."}

    try:
        if item_type == "laptop":
            if not os.path.isfile(LAPTOP_MODEL_PATH):
                return {"error": f"laptop_damage.pt not found at {LAPTOP_MODEL_PATH} - "
                                  f"upload the model file directly into this Space's files."}
            result = detect_damage_hybrid(
                image_path=crop_image, model_path=LAPTOP_MODEL_PATH, item_type=item_type,
                vlm_change_score=change_score, baseline_path=baseline_image, return_path=return_image,
            )
        else:
            result = detect_damage_vlm_only(
                image_path=crop_image, item_type=item_type,
                change_score=change_score, baseline_path=baseline_image, return_path=return_image,
            )

        # FIX: "description" already always defaults to "" (never a missing
        # key) inside result["vlm_assessment"]["description"] - confirmed
        # directly in damage_type_classifier.py. Adding a TOP-LEVEL alias
        # here too, since the real integration issue may be a caller
        # reading result["description"] directly instead of the nested
        # path - this way it works either way, regardless of which it is.
        result["description"] = result.get("vlm_assessment", {}).get("description", "")

        return result
    except Exception as e:
        return {"error": f"Agent 2 processing failed: {e}"}


with gr.Blocks(title="Agent 2 - Visual Damage Classification") as demo:
    gr.Markdown("# Agent 2 - Visual Damage-Type Classification\n"
                "Given a flagged photo region from Agent 1, identifies the damage type and severity. "
                "Combines a trained detector (laptop only) with a vision-language model (all item types).")

    # allow_custom_value=True: same fix as Agent 4 - lets an invalid value reach
    # our own validation instead of Gradio crashing on it first.
    item_type_input = gr.Dropdown(label="Item Type", choices=ITEM_TYPES, allow_custom_value=True)
    crop_input = gr.Image(label="Flagged Crop (from Agent 1)", type="filepath")
    change_score_input = gr.Slider(label="Agent 1's Change Score", minimum=0.0, maximum=1.0, value=0.5, step=0.01)

    gr.Markdown("**Optional** - the full baseline/return photos, so the model can check whether "
                "this damage is genuinely new or already present in the baseline:")
    with gr.Row():
        baseline_input = gr.Image(label="Full Baseline Photo (optional)", type="filepath")
        return_input = gr.Image(label="Full Return Photo (optional)", type="filepath")

    with gr.Row():
        submit_btn = gr.Button("Classify Damage", variant="primary")
        clear_btn = gr.ClearButton(
            value="Clear All (start a fresh test)",
            components=[item_type_input, crop_input, change_score_input, baseline_input, return_input],
        )

    output = gr.JSON(label="Result")
    clear_btn.add(output)

    submit_btn.click(
        fn=process,
        inputs=[item_type_input, crop_input, change_score_input, baseline_input, return_input],
        outputs=output,
        api_name="classify",
    )

if __name__ == "__main__":
    demo.launch()
