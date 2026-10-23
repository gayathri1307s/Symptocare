import io
from pathlib import Path

import pytesseract
from PIL import Image, ImageOps
from pypdf import PdfReader
from pdf2image import convert_from_bytes


SUPPORTED_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg"}


def extract_text_from_report(
    file_bytes: bytes,
    filename: str,
) -> dict:
    """Extract text from digital PDFs, scanned PDFs, and report images."""

    extension = Path(filename).suffix.lower()

    if extension not in SUPPORTED_EXTENSIONS:
        raise ValueError(
            "Unsupported file type. Upload a PDF, PNG, or JPG."
        )

    try:
        if extension == ".pdf":
            reader = PdfReader(io.BytesIO(file_bytes))

            text = "\n".join(
                page.extract_text() or ""
                for page in reader.pages
            ).strip()

            if text:
                method = "pdf_text"
            else:
                images = convert_from_bytes(file_bytes, dpi=250)
                text = "\n".join(
                    pytesseract.image_to_string(
                        image,
                        config="--psm 6",
                    )
                    for image in images
                ).strip()
                method = "ocr"

        else:
            image = Image.open(io.BytesIO(file_bytes))
            image = ImageOps.exif_transpose(image).convert("RGB")

            text = pytesseract.image_to_string(
                image,
                config="--psm 6",
            ).strip()
            method = "ocr"

    except Exception as exc:
        raise ValueError(
            f"Could not read the report: {exc}"
        ) from exc

    if not text:
        raise ValueError(
            "No readable text was found in the report."
        )

    return {
        "filename": Path(filename).name,
        "extraction_method": method,
        "extracted_text": text,
    }
