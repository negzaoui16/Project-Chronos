"""
Agent 2 - Visual Damage-Type Classifier
------------------------------------------
Takes the flagged region crop from Agent 1 (plus its change_score and
reliability signals) and identifies WHICH KIND of damage it is, using a
Vision-Language Model (Gemini, same free-tier choice as Agent 3) - zero
training, zero fine-tuning, same philosophy as the rest of Module 2.

Classifies into exactly one of the 9 shared taxonomy categories:
  screen_display, structural_body, port_connector, missing_component,
  liquid_moisture, input_control, power_boot_failure, cosmetic_wear,
  other_unclassified

Self-consistency: calls the VLM multiple times on the same crop and checks
agreement - if the calls disagree on damage_type, that's flagged for human
review rather than silently picking one guess. Same honest-about-uncertainty
pattern used throughout Agent 1.
"""

import os
import json
import re
from collections import Counter
from dataclasses import dataclass, field

from google import genai
from google.genai import types


VLM_MODEL = "gemini-1.5-flash"
SELF_CONSISTENCY_CALLS = 3          # how many times to classify the same crop
AGREEMENT_THRESHOLD = 0.6           # fraction of calls that must agree on damage_type
                                     # to trust it without flagging for human review

# The shared taxonomy - must match damage_knowledge_base.py and the rest of Module 2
DAMAGE_CATEGORIES = {
    "screen_display": "Cracked/scratched screen, dead pixels, flickering, no image/blank display, discoloration.",
    "structural_body": "Cracked/broken casing, dents, warping, broken hinge, missing structural piece.",
    "port_connector": "Damaged, bent, or loose port/connector (charging port, USB, HDMI, etc.).",
    "missing_component": "A part, cable, or accessory that should be present is visibly missing.",
    "liquid_moisture": "Visible liquid residue, staining, or corrosion consistent with a spill.",
    "input_control": "Broken/missing key, stuck button, damaged touchpad/touchscreen surface, broken control.",
    "power_boot_failure": "Visible signs consistent with power/battery failure (e.g. swelling, burn marks near battery) - "
                           "NOTE: most power/boot failures have no visible symptom at all and should come from Agent 3, "
                           "not this agent; only use this category if there IS a visible physical sign.",
    "cosmetic_wear": "Minor scuffs, scratches, or wear that does not affect function.",
    "other_unclassified": "Visible damage that doesn't clearly fit any category above, or the image is unclear/ambiguous.",
}

SEVERITY_LEVELS = ["Cosmetic", "Moderate", "Severe", "Critical"]


@dataclass
class DamageClassification:
    damage_type: str = None
    damage_level: str = None
    confidence: float = 0.0
    description: str = ""
    is_new_damage: bool = True
    raw_response: str = ""
    parse_ok: bool = True
    error: str = None


@dataclass
class ConsistencyResult:
    final_damage_type: str = None
    final_damage_level: str = None
    final_description: str = ""
    is_new_damage: bool = True
    agreement_ratio: float = 0.0
    requires_human_review: bool = True
    individual_calls: list = field(default_factory=list)


def _build_prompt(item_type, change_score, alignment_warning=None, resolution_warning=None,
                   has_full_context=False):
    """
    Build the classification prompt, including Agent 1's own diagnostics as
    context - NOT as ground truth, since Agent 1's confidence issues should
    make Agent 2 more cautious, not less.

    has_full_context: True when the full baseline and return photos are
    ALSO provided (not just the crop) - adds an explicit instruction to
    check whether the flagged mark is genuinely NEW (only visible in the
    return photo) or PRE-EXISTING (already visible in the baseline photo,
    e.g. an old scratch the item already had at pickup). Pre-existing
    damage should not be flagged as new damage from this session, even if
    Agent 1's pixel-level diff picked up a region near it.
    """
    category_list = "\n".join(f'  - "{name}": {desc}' for name, desc in DAMAGE_CATEGORIES.items())

    context_notes = []
    if alignment_warning:
        context_notes.append(
            f"NOTE: the automated pre-screening flagged an alignment issue: \"{alignment_warning}\" "
            f"- treat the change_score below as less reliable than usual."
        )
    if resolution_warning:
        context_notes.append(f"NOTE: {resolution_warning}")
    context_block = ("\n".join(context_notes) + "\n") if context_notes else ""

    new_vs_old_instruction = ""
    if has_full_context:
        new_vs_old_instruction = (
            "\nYou have also been given the FULL baseline (pickup) and return photos, not just "
            "the cropped region - use them to check whether the damage shown in the crop is "
            "GENUINELY NEW (visible in the return photo but NOT in the baseline photo) or "
            "PRE-EXISTING (the same mark is already visible in the baseline photo - e.g. an old "
            "scratch or dent the item already had at pickup, which the automated crop detector "
            "may have flagged again due to lighting/angle differences, not because anything "
            "actually changed). If the damage is pre-existing rather than new, set "
            "\"is_new_damage\": false and explain this in your description - pre-existing damage "
            "should not be attributed to this rental session.\n"
        )

    return f"""You are inspecting a cropped photo region of a {item_type} that was automatically \
flagged as visually changed between a pickup photo and a return photo.

Automated pre-screening change_score: {change_score} (0-1 scale, higher = more visual difference \
detected by pixel-level comparison - this is a rough signal, not a judgment of damage type or severity).
{context_block}{new_vs_old_instruction}
Classify the damage shown in this image into EXACTLY ONE of these categories:
{category_list}

Also rate severity as one of: {", ".join(SEVERITY_LEVELS)}.
- Cosmetic: minor, does not affect function.
- Moderate: visible damage, item still usable.
- Severe: damage impairs normal use.
- Critical: item non-functional or unsafe.

If the image is unclear, ambiguous, or doesn't show a clear physical defect, use "other_unclassified" \
and a low confidence score rather than guessing.

Respond with ONLY a JSON object in this exact shape, nothing else - no preamble, no markdown fences:
{{"damage_type": "screen_display", "damage_level": "Severe", "confidence": 0.85, "is_new_damage": true, "description": "A short, human-readable description of what you see, for an admin dashboard."}}
"""


def _read_image_part(image_path):
    with open(image_path, "rb") as f:
        data = f.read()
    mime_type = "image/png" if image_path.lower().endswith(".png") else "image/jpeg"
    return types.Part.from_bytes(data=data, mime_type=mime_type)


def _parse_json_response(text):
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.strip("`")
        if cleaned.lower().startswith("json"):
            cleaned = cleaned[4:]
    return json.loads(cleaned.strip())


def classify_damage_single_call(crop_path, item_type, change_score, client=None,
                                 baseline_path=None, return_path=None,
                                 alignment_warning=None, resolution_warning=None) -> DamageClassification:
    """
    One VLM call classifying a single crop. Optionally includes the full
    baseline/return photos for context - both for cases like a crack near
    a hinge reading differently than one mid-screen, AND (the main reason
    this is now used by default from Agent 2's real entry points) so the
    model can distinguish genuinely NEW damage from PRE-EXISTING damage the
    item already had at pickup.
    """
    if client is None:
        client = genai.Client(api_key=os.environ.get("GOOGLE_API_KEY"))

    has_full_context = baseline_path is not None and return_path is not None
    prompt = _build_prompt(item_type, change_score, alignment_warning, resolution_warning,
                            has_full_context=has_full_context)

    contents = [_read_image_part(crop_path)]
    if baseline_path:
        contents.append("(This is the BASELINE/pickup photo for context:)")
        contents.append(_read_image_part(baseline_path))
    if return_path:
        contents.append("(This is the RETURN photo for context:)")
        contents.append(_read_image_part(return_path))
    contents.append(prompt)

    raw_text = ""
    try:
        response = client.models.generate_content(
            model=VLM_MODEL,
            contents=contents,
            config=types.GenerateContentConfig(temperature=0.2),  # low but non-zero - slight
                                                                    # variation across the self-
                                                                    # consistency calls is useful signal
        )
        raw_text = response.text
        parsed = _parse_json_response(raw_text)

        damage_type = parsed.get("damage_type")
        if damage_type not in DAMAGE_CATEGORIES:
            damage_type = "other_unclassified"

        damage_level = parsed.get("damage_level")
        if damage_level not in SEVERITY_LEVELS:
            damage_level = "Moderate"

        return DamageClassification(
            damage_type=damage_type,
            damage_level=damage_level,
            confidence=float(parsed.get("confidence", 0.5)),
            description=parsed.get("description", ""),
            is_new_damage=bool(parsed.get("is_new_damage", True)),
            raw_response=raw_text,
            parse_ok=True,
        )

    except (json.JSONDecodeError, KeyError, ValueError) as e:
        return DamageClassification(raw_response=raw_text, parse_ok=False,
                                     error=f"Failed to parse VLM response: {e}")
    except Exception as e:
        return DamageClassification(parse_ok=False, error=f"VLM call failed: {e}")


def classify_damage_with_consistency(crop_path, item_type, change_score,
                                      baseline_path=None, return_path=None,
                                      alignment_warning=None, resolution_warning=None,
                                      n_calls=SELF_CONSISTENCY_CALLS,
                                      api_key=None) -> ConsistencyResult:
    """
    Main entry point for Agent 2. Calls the VLM classifier N times on the
    same crop and checks agreement, instead of trusting a single call.

    If the calls agree strongly on damage_type: trust it, requires_human_review=False.
    If they disagree: still return the most common answer as a best guess,
    but flag requires_human_review=True so a human/Agent 4 double-checks
    rather than the system silently acting on an uncertain classification.
    """
    client = genai.Client(api_key=api_key or os.environ.get("GOOGLE_API_KEY"))

    calls = []
    for _ in range(n_calls):
        result = classify_damage_single_call(
            crop_path, item_type, change_score, client=client,
            baseline_path=baseline_path, return_path=return_path,
            alignment_warning=alignment_warning, resolution_warning=resolution_warning,
        )
        calls.append(result)

    valid_calls = [c for c in calls if c.parse_ok]
    if not valid_calls:
        return ConsistencyResult(
            final_damage_type="other_unclassified",
            final_damage_level="Moderate",
            final_description="Classification failed - all VLM calls errored.",
            is_new_damage=True,
            agreement_ratio=0.0,
            requires_human_review=True,
            individual_calls=[c.__dict__ for c in calls],
        )

    type_counts = Counter(c.damage_type for c in valid_calls)
    most_common_type, count = type_counts.most_common(1)[0]
    agreement_ratio = count / len(valid_calls)

    # among calls that agree with the majority, use the one with highest
    # confidence for the final severity/description
    agreeing_calls = [c for c in valid_calls if c.damage_type == most_common_type]
    best_call = max(agreeing_calls, key=lambda c: c.confidence)

    # is_new_damage: trust it only if the calls that agree on damage_type
    # ALSO agree it's new - a mixed signal here should default to treating
    # it as new (safer default - a real new defect should not slip through
    # unflagged just because the model was uncertain about its age)
    new_damage_votes = [c.is_new_damage for c in agreeing_calls]
    is_new_damage = sum(new_damage_votes) >= len(new_damage_votes) / 2

    return ConsistencyResult(
        final_damage_type=most_common_type,
        final_damage_level=best_call.damage_level,
        final_description=best_call.description,
        is_new_damage=is_new_damage,
        agreement_ratio=round(agreement_ratio, 2),
        requires_human_review=(agreement_ratio < AGREEMENT_THRESHOLD),
        individual_calls=[
            {"damage_type": c.damage_type, "damage_level": c.damage_level,
             "confidence": c.confidence, "is_new_damage": c.is_new_damage}
            for c in valid_calls
        ],
    )
