import logging
from pathlib import Path

from PIL import Image

logger = logging.getLogger(__name__)

_ocr_engine = None


def get_ocr_engine():
    """Lazy-load PaddleOCR (GPU model loading takes a few seconds)."""
    global _ocr_engine
    if _ocr_engine is None:
        from paddleocr import PaddleOCR

        logger.info("Loading PaddleOCR model (GPU)...")
        _ocr_engine = PaddleOCR(
            use_angle_cls=True,
            lang="japan",
            use_gpu=True,
            show_log=False,
        )
        logger.info("PaddleOCR model loaded.")
    return _ocr_engine


class OcrResult:
    def __init__(self, lines: list[dict], raw_text: str):
        self.lines = lines
        self.raw_text = raw_text


def run_ocr(image_path: str) -> OcrResult:
    """Run OCR on an image file. Returns structured line results and raw text."""
    ocr = get_ocr_engine()
    results = ocr.ocr(image_path, cls=True)

    lines = []
    text_parts = []

    if results and results[0]:
        for line in results[0]:
            box = line[0]  # [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]
            text = line[1][0]
            confidence = float(line[1][1])

            lines.append(
                {
                    "text": text,
                    "confidence": confidence,
                    "box": {
                        "top_left": box[0],
                        "top_right": box[1],
                        "bottom_right": box[2],
                        "bottom_left": box[3],
                    },
                }
            )
            text_parts.append(text)

    raw_text = "\n".join(text_parts)
    return OcrResult(lines=lines, raw_text=raw_text)


def extract_seed_packet_info(ocr_result: OcrResult) -> dict:
    """Extract structured info from seed packet OCR text.

    Attempts to identify crop name, variety, and key cultivation data
    from the raw OCR output using simple pattern matching.
    """
    text = ocr_result.raw_text
    info = {
        "raw_text": text,
        "crop_name": "",
        "variety": "",
        "lines": [line["text"] for line in ocr_result.lines],
    }

    # The first few high-confidence lines are typically the crop name
    high_conf_lines = [
        line for line in ocr_result.lines if line["confidence"] > 0.8
    ]
    if high_conf_lines:
        # Usually the largest text (crop name) is near the top
        info["crop_name_candidates"] = [
            line["text"] for line in high_conf_lines[:3]
        ]

    return info
