"""メール送信 — ローカル Postfix 経由（DKIM 署名済み）

サーバーの Postfix + OpenDKIM を利用して送信する。
外部 SMTP サーバーは不要。
"""

import asyncio
import logging
from email.message import EmailMessage

from config import settings

logger = logging.getLogger(__name__)


async def send_mail(*, to: str, subject: str, body: str) -> bool:
    """sendmail コマンドでメールを送信する。

    Postfix が DKIM 署名を付けてくれるので、ここでは本文を渡すだけ。
    """
    msg = EmailMessage()
    msg["From"] = settings.mail_from
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)

    try:
        proc = await asyncio.create_subprocess_exec(
            "/usr/sbin/sendmail", "-t", "-i",
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, stderr = await proc.communicate(msg.as_bytes())

        if proc.returncode != 0:
            logger.error("sendmail failed (%d): %s", proc.returncode, stderr.decode())
            return False

        logger.info("Mail sent to %s: %s", to, subject)
        return True
    except FileNotFoundError:
        logger.error("sendmail not found. Is Postfix installed?")
        return False
    except Exception as e:
        logger.error("Mail send error: %s", e)
        return False


async def send_site_ready(*, to: str, username: str, url: str) -> bool:
    """サイト公開完了通知メールを送信する。"""
    return await send_mail(
        to=to,
        subject=f"サイトが公開されました — {username}",
        body=(
            f"{username} さん\n"
            f"\n"
            f"あなたの農園サイトが公開されました。\n"
            f"\n"
            f"公開URL: {url}\n"
            f"\n"
            f"内容の更新はアプリの Web タブから行えます。\n"
            f"\n"
            f"— 自然栽培 Cowork\n"
        ),
    )


async def send_site_error(*, to: str, username: str, error: str) -> bool:
    """サイト生成エラー通知メールを送信する。"""
    return await send_mail(
        to=to,
        subject=f"サイト生成でエラーが発生しました — {username}",
        body=(
            f"{username} さん\n"
            f"\n"
            f"サイトの生成中にエラーが発生しました。\n"
            f"\n"
            f"エラー内容: {error}\n"
            f"\n"
            f"データを確認の上、再度お試しください。\n"
            f"\n"
            f"— 自然栽培 Cowork\n"
        ),
    )
