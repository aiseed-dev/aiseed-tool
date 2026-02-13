"""農家ホームページの HTML テンプレート生成

栽培記録データから静的 HTML を生成する。外部依存なし。
"""

from __future__ import annotations

import html
from datetime import datetime


def generate_site_html(
    *,
    farm_name: str,
    farm_description: str = "",
    farm_location: str = "",
    farm_policy: str = "",
    crops: list[dict] | None = None,
    sales: dict | None = None,
) -> str:
    """テンプレートベースの HTML を生成して返す。"""
    crops = crops or []
    sales = sales or {}
    _e = html.escape

    crop_cards = "\n".join(_crop_card(c, _e) for c in crops)

    sales_items = sales.get("items", [])
    sales_desc = sales.get("description", "")
    sales_contact = sales.get("contact", "")

    sales_rows = "\n".join(
        f'          <tr><td>{_e(i["name"])}</td>'
        f'<td class="price">{_e(i["price"])}</td>'
        f'<td>{_e(i.get("note", ""))}</td></tr>'
        for i in sales_items
    )

    has_sales = bool(sales_items or sales_desc)
    has_contact = bool(sales_contact)
    year = datetime.now().year

    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{_e(farm_name)}</title>
  <meta name="description" content="{_e(farm_description[:160])}">
  <style>
{SITE_CSS}
  </style>
</head>
<body>

<header class="site-header">
  <div class="header-inner">
    <h1 class="farm-name">{_e(farm_name)}</h1>
    <nav>
      <a href="#about">農園について</a>
      <a href="#crops">作物</a>
      {'<a href="#sales">販売</a>' if has_sales else ''}
      {'<a href="#contact">お問い合わせ</a>' if has_contact else ''}
    </nav>
  </div>
</header>

<main>
  <section id="about" class="section">
    <div class="section-inner">
      <h2>農園について</h2>
      <p class="farm-description">{_e(farm_description)}</p>
      {f'<p class="farm-meta"><span class="label">所在地</span>{_e(farm_location)}</p>' if farm_location else ''}
      {f'<p class="farm-meta"><span class="label">栽培方針</span>{_e(farm_policy)}</p>' if farm_policy else ''}
    </div>
  </section>

  <section id="crops" class="section">
    <div class="section-inner">
      <h2>作物紹介</h2>
      <div class="crop-grid">
        {crop_cards}
      </div>
    </div>
  </section>

  {_sales_section(sales_desc, sales_rows, _e) if has_sales else ''}

  {_contact_section(sales_contact, _e) if has_contact else ''}
</main>

<footer>
  <p>&copy; {year} {_e(farm_name)}</p>
</footer>

</body>
</html>"""


def _crop_card(crop: dict, _e) -> str:
    name = crop.get("cultivationName", "")
    variety = crop.get("variety", "")
    desc = crop.get("description", "")
    photos = crop.get("photoUrls", [])

    photo_html = ""
    if photos:
        imgs = "\n            ".join(
            f'<img src="{_e(url)}" alt="{_e(name)}" loading="lazy">'
            for url in photos
        )
        photo_html = f'<div class="crop-photos">\n            {imgs}\n          </div>'

    return f"""      <article class="crop-card">
        {photo_html}
        <div class="crop-info">
          <h3>{_e(name)}</h3>
          {f'<p class="crop-variety">{_e(variety)}</p>' if variety else ''}
          {f'<p>{_e(desc)}</p>' if desc else ''}
        </div>
      </article>"""


def _sales_section(desc: str, rows: str, _e) -> str:
    return f"""  <section id="sales" class="section">
    <div class="section-inner">
      <h2>販売情報</h2>
      {f'<p>{_e(desc)}</p>' if desc else ''}
      {f'''<div class="table-wrap">
        <table>
          <thead><tr><th>商品</th><th>価格</th><th>備考</th></tr></thead>
          <tbody>{rows}
          </tbody>
        </table>
      </div>''' if rows else ''}
    </div>
  </section>"""


def _contact_section(contact: str, _e) -> str:
    return f"""  <section id="contact" class="section">
    <div class="section-inner">
      <h2>お問い合わせ</h2>
      <p class="contact">{_e(contact)}</p>
    </div>
  </section>"""


SITE_CSS = """\
    :root {
      --color-bg: #faf9f6;
      --color-surface: #ffffff;
      --color-text: #2c2c2c;
      --color-text-sub: #5a5a5a;
      --color-accent: #4a7c59;
      --color-accent-light: #e8f0eb;
      --color-border: #e0ddd8;
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    html { font-size: 16px; scroll-behavior: smooth; }

    body {
      font-family: "Hiragino Kaku Gothic ProN", "Hiragino Sans", Meiryo, sans-serif;
      color: var(--color-text);
      background: var(--color-bg);
      line-height: 1.8;
    }

    .site-header {
      background: var(--color-surface);
      border-bottom: 1px solid var(--color-border);
      padding: 1rem 1.5rem;
      position: sticky;
      top: 0;
      z-index: 100;
    }

    .header-inner {
      max-width: 960px;
      margin: 0 auto;
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 0.5rem;
    }

    .farm-name {
      font-size: 1.2rem;
      font-weight: 700;
      color: var(--color-accent);
    }

    nav a {
      font-size: 0.85rem;
      color: var(--color-text-sub);
      text-decoration: none;
      margin-left: 1.2rem;
    }
    nav a:hover { color: var(--color-accent); }

    .section { padding: 3rem 1.5rem; }
    .section:nth-child(even) { background: var(--color-surface); }

    .section-inner {
      max-width: 960px;
      margin: 0 auto;
    }

    h2 {
      font-size: 1.4rem;
      font-weight: 700;
      color: var(--color-accent);
      margin-bottom: 1.2rem;
      padding-bottom: 0.4rem;
      border-bottom: 2px solid var(--color-accent-light);
    }

    .farm-description { font-size: 1rem; margin-bottom: 1rem; }

    .farm-meta { font-size: 0.9rem; color: var(--color-text-sub); margin-bottom: 0.3rem; }
    .farm-meta .label { display: inline-block; min-width: 5em; font-weight: 600; color: var(--color-text); }

    .crop-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 1.5rem;
    }

    .crop-card {
      background: var(--color-surface);
      border: 1px solid var(--color-border);
      border-radius: 8px;
      overflow: hidden;
    }

    .crop-photos { display: flex; overflow-x: auto; scroll-snap-type: x mandatory; }
    .crop-photos img { width: 100%; min-width: 100%; height: 220px; object-fit: cover; scroll-snap-align: start; }

    .crop-info { padding: 1rem 1.2rem; }
    .crop-info h3 { font-size: 1.1rem; color: var(--color-text); margin-bottom: 0.3rem; }
    .crop-variety { font-size: 0.85rem; color: var(--color-text-sub); font-style: italic; margin-bottom: 0.5rem; }
    .crop-info p { font-size: 0.9rem; color: var(--color-text-sub); }

    .table-wrap { overflow-x: auto; margin-top: 1rem; }
    table { width: 100%; border-collapse: collapse; }
    th { background: var(--color-accent-light); font-weight: 600; text-align: left; padding: 0.6rem 0.8rem; font-size: 0.9rem; border-bottom: 2px solid var(--color-border); }
    td { padding: 0.5rem 0.8rem; font-size: 0.9rem; border-bottom: 1px solid var(--color-border); }
    .price { font-weight: 600; white-space: nowrap; }

    .contact { font-size: 1rem; white-space: pre-wrap; }

    footer { text-align: center; padding: 2rem; font-size: 0.8rem; color: var(--color-text-sub); border-top: 1px solid var(--color-border); }

    @media (max-width: 640px) {
      html { font-size: 15px; }
      .header-inner { flex-direction: column; text-align: center; }
      nav a { margin: 0 0.5rem; }
      .crop-grid { grid-template-columns: 1fr; }
      .section { padding: 2rem 1rem; }
    }"""
