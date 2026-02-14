"""サイト生成・デプロイ — 農家ホームページ

スマホ版: テンプレートベースのバッチ処理
PC版: 即時生成 + ユーザーの Cloudflare にデプロイ
"""

import json
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select

from database import AsyncSession, get_db
from models.site_job import SiteJob
from routers.auth import get_current_user
from services.site_template import generate_site_html

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sites", tags=["sites"])


# ── リクエストモデル ──


class SiteCrop(BaseModel):
    cultivationName: str
    variety: str = ""
    description: str = ""
    photoUrls: list[str] = []


class SiteSales(BaseModel):
    description: str = ""
    contact: str = ""
    items: list[dict] = []


class SiteData(BaseModel):
    farmName: str
    farmDescription: str = ""
    farmLocation: str = ""
    farmPolicy: str = ""
    farmUsername: str = ""
    crops: list[SiteCrop] = []
    sales: SiteSales = SiteSales()


class DeployRequest(BaseModel):
    site: SiteData
    cfAccountId: str
    cfApiToken: str
    projectName: str


# ── 即時生成（PC版） ──


@router.post("/generate")
async def generate(data: SiteData, request: Request, user=Depends(get_current_user)):
    """テンプレートから HTML を即時生成して返す。"""
    api_base = str(request.base_url).rstrip("/")
    html = generate_site_html(
        farm_name=data.farmName,
        farm_description=data.farmDescription,
        farm_location=data.farmLocation,
        farm_policy=data.farmPolicy,
        crops=[c.model_dump() for c in data.crops],
        sales=data.sales.model_dump(),
        farm_username=data.farmUsername or user.username,
        api_base_url=api_base,
    )
    return {"html": html, "size": len(html.encode("utf-8"))}


# ── バッチリクエスト（スマホ版） ──


@router.post("/request")
async def request_generation(
    data: SiteData,
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """バッチ処理キューにリクエストを追加する。"""
    job = SiteJob(
        user_id=user.id,
        site_data=json.dumps(data.model_dump(), ensure_ascii=False),
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)
    return {"job_id": job.id, "status": job.status}


@router.get("/status/{job_id}")
async def job_status(
    job_id: str,
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """バッチジョブの状態を確認する。"""
    result = await db.execute(
        select(SiteJob).where(SiteJob.id == job_id, SiteJob.user_id == user.id)
    )
    job = result.scalar_one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    resp = {"job_id": job.id, "status": job.status, "created_at": job.created_at}
    if job.status == "done":
        resp["public_url"] = job.public_url
    elif job.status == "error":
        resp["error"] = job.error_message
    return resp


@router.get("/jobs")
async def list_jobs(
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """ユーザーのジョブ一覧を返す。"""
    result = await db.execute(
        select(SiteJob)
        .where(SiteJob.user_id == user.id)
        .order_by(SiteJob.created_at.desc())
        .limit(20)
    )
    jobs = result.scalars().all()
    return [
        {
            "job_id": j.id,
            "status": j.status,
            "public_url": j.public_url,
            "created_at": j.created_at,
        }
        for j in jobs
    ]


# ── Cloudflare Pages デプロイ（PC版） ──


@router.post("/deploy")
async def deploy(req: DeployRequest, request: Request, user=Depends(get_current_user)):
    """ユーザーの Cloudflare Pages にデプロイする。"""
    api_base = str(request.base_url).rstrip("/")
    html = generate_site_html(
        farm_name=req.site.farmName,
        farm_description=req.site.farmDescription,
        farm_location=req.site.farmLocation,
        farm_policy=req.site.farmPolicy,
        crops=[c.model_dump() for c in req.site.crops],
        sales=req.site.sales.model_dump(),
        farm_username=req.site.farmUsername or user.username,
        api_base_url=api_base,
    )

    cf_base = f"https://api.cloudflare.com/client/v4/accounts/{req.cfAccountId}"
    headers = {"Authorization": f"Bearer {req.cfApiToken}"}

    async with httpx.AsyncClient(timeout=60) as client:
        # プロジェクトが存在しなければ作成
        check = await client.get(
            f"{cf_base}/pages/projects/{req.projectName}", headers=headers
        )
        if check.status_code == 404:
            create_resp = await client.post(
                f"{cf_base}/pages/projects",
                headers=headers,
                json={"name": req.projectName, "production_branch": "main"},
            )
            if create_resp.status_code not in (200, 201):
                raise HTTPException(
                    status_code=502,
                    detail=f"Cloudflare project creation failed: {create_resp.text}",
                )

        # Direct Upload でデプロイ
        deploy_resp = await client.post(
            f"{cf_base}/pages/projects/{req.projectName}/deployments",
            headers=headers,
            files={"index.html": ("index.html", html.encode("utf-8"), "text/html")},
        )

        if deploy_resp.status_code not in (200, 201):
            raise HTTPException(
                status_code=502,
                detail=f"Cloudflare deploy failed: {deploy_resp.text}",
            )

        result = deploy_resp.json().get("result", {})
        return {
            "url": result.get("url", ""),
            "projectUrl": f"https://{req.projectName}.pages.dev",
        }
