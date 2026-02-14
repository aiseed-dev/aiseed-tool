"""QRコード生成エンドポイント。

ホームページ URL から印刷用の QR コード画像を生成する。
マルシェの値札、畑の看板、野菜の袋に貼って直販に誘導する。
"""

import io
import logging

from fastapi import APIRouter, Query
from fastapi.responses import StreamingResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/qr", tags=["qr"])


def _generate_qr_png(
    data: str,
    box_size: int = 10,
    border: int = 4,
) -> bytes:
    """QR コードを PNG バイト列として生成する。"""
    import qrcode
    from qrcode.image.pil import PilImage

    qr = qrcode.QRCode(
        version=None,  # 自動サイズ
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=box_size,
        border=border,
    )
    qr.add_data(data)
    qr.make(fit=True)

    img: PilImage = qr.make_image(fill_color="black", back_color="white")

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _generate_qr_svg(
    data: str,
    box_size: int = 10,
    border: int = 4,
) -> str:
    """QR コードを SVG 文字列として生成する。"""
    import qrcode
    import qrcode.image.svg

    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=box_size,
        border=border,
    )
    qr.add_data(data)
    qr.make(fit=True)

    factory = qrcode.image.svg.SvgPathImage
    img = qr.make_image(image_factory=factory)

    buf = io.BytesIO()
    img.save(buf)
    return buf.getvalue().decode("utf-8")


@router.get("/generate")
async def generate_qr(
    url: str = Query(..., description="QRコードに埋め込む URL"),
    size: int = Query(default=10, ge=1, le=40, description="ドットサイズ（1-40）"),
    format: str = Query(default="png", description="出力形式: png or svg"),
):
    """URL から QR コード画像を生成する。

    印刷用途に対応:
    - PNG: 看板・値札用（高解像度）
    - SVG: 拡大しても綺麗（ポスター向け）
    """
    if format == "svg":
        svg = _generate_qr_svg(url, box_size=size)
        return StreamingResponse(
            io.BytesIO(svg.encode("utf-8")),
            media_type="image/svg+xml",
            headers={
                "Content-Disposition": f'inline; filename="qr.svg"',
                "Cache-Control": "public, max-age=86400",
            },
        )

    png = _generate_qr_png(url, box_size=size)
    return StreamingResponse(
        io.BytesIO(png),
        media_type="image/png",
        headers={
            "Content-Disposition": f'inline; filename="qr.png"',
            "Cache-Control": "public, max-age=86400",
        },
    )
