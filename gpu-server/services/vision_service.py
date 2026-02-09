import logging
from PIL import Image

from config import settings

logger = logging.getLogger(__name__)

_model = None
_processor = None


def get_florence():
    """Lazy-load Florence-2 model (GPU)."""
    global _model, _processor
    if _model is None:
        import torch
        from transformers import AutoProcessor, AutoModelForCausalLM

        model_id = settings.florence_model
        logger.info(f"Loading Florence-2 model: {model_id} ...")

        _processor = AutoProcessor.from_pretrained(model_id, trust_remote_code=True)
        _model = AutoModelForCausalLM.from_pretrained(
            model_id,
            torch_dtype=torch.float16,
            trust_remote_code=True,
        ).to("cuda")

        logger.info("Florence-2 model loaded on GPU.")
    return _model, _processor


def run_caption(image_path: str) -> str:
    """Generate a detailed caption for the image."""
    model, processor = get_florence()
    image = Image.open(image_path).convert("RGB")

    prompt = "<MORE_DETAILED_CAPTION>"
    inputs = processor(text=prompt, images=image, return_tensors="pt").to(
        "cuda", model.dtype
    )

    import torch

    with torch.inference_mode():
        generated_ids = model.generate(
            **inputs, max_new_tokens=512, num_beams=3
        )

    result = processor.batch_decode(generated_ids, skip_special_tokens=False)[0]
    parsed = processor.post_process_generation(
        result, task=prompt, image_size=image.size
    )
    return parsed.get(prompt, result)


def run_detect(image_path: str, target: str = "") -> dict:
    """Detect and locate objects in the image.

    If target is provided, uses open-vocabulary detection for that object.
    Otherwise uses general object detection.
    """
    model, processor = get_florence()
    image = Image.open(image_path).convert("RGB")

    if target:
        prompt = "<OPEN_VOCABULARY_DETECTION>"
        text_input = prompt + target
    else:
        prompt = "<OD>"
        text_input = prompt

    inputs = processor(text=text_input, images=image, return_tensors="pt").to(
        "cuda", model.dtype
    )

    import torch

    with torch.inference_mode():
        generated_ids = model.generate(
            **inputs, max_new_tokens=512, num_beams=3
        )

    result = processor.batch_decode(generated_ids, skip_special_tokens=False)[0]
    parsed = processor.post_process_generation(
        result, task=prompt, image_size=image.size
    )
    return parsed.get(prompt, {})


def analyze_plant_photo(image_path: str) -> dict:
    """Analyze a plant/garden photo.

    Returns caption, and detected objects.
    """
    caption = run_caption(image_path)
    detections = run_detect(image_path)

    return {
        "caption": caption,
        "detections": detections,
    }
