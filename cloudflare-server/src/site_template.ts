/**
 * ユーザーホームページの HTML テンプレート
 *
 * ユーザーの農園情報・作物・販売情報から静的 HTML を生成する。
 * 生成された HTML は単体で動作し、外部依存なし。
 */

export interface SiteData {
  /** 農園名 */
  farmName: string;
  /** 農園の説明 */
  farmDescription: string;
  /** 所在地 */
  farmLocation: string;
  /** 栽培方針 (例: 自然栽培、有機栽培) */
  farmPolicy: string;
  /** 作物一覧 */
  crops: SiteCrop[];
  /** 販売情報 */
  sales: SiteSales;
}

export interface SiteCrop {
  /** 栽培名 */
  cultivationName: string;
  /** 品種名 */
  variety: string;
  /** 説明 */
  description: string;
  /** 写真 URL 一覧 (R2 の公開 URL) */
  photoUrls: string[];
}

export interface SiteSales {
  /** 販売方法の説明 */
  description: string;
  /** 連絡先 (メール, 電話など) */
  contact: string;
  /** 価格表の項目 */
  items: SalesItem[];
}

export interface SalesItem {
  name: string;
  price: string;
  note: string;
}

export function generateSiteHtml(data: SiteData): string {
  const cropCards = data.crops
    .map(
      (crop) => `
      <article class="crop-card">
        ${
          crop.photoUrls.length > 0
            ? `<div class="crop-photos">
            ${crop.photoUrls.map((url) => `<img src="${escapeHtml(url)}" alt="${escapeHtml(crop.cultivationName)}" loading="lazy">`).join("\n            ")}
          </div>`
            : ""
        }
        <div class="crop-info">
          <h3>${escapeHtml(crop.cultivationName)}</h3>
          ${crop.variety ? `<p class="crop-variety">${escapeHtml(crop.variety)}</p>` : ""}
          ${crop.description ? `<p>${escapeHtml(crop.description)}</p>` : ""}
        </div>
      </article>`,
    )
    .join("\n");

  const salesItems = data.sales.items
    .map(
      (item) => `
          <tr>
            <td>${escapeHtml(item.name)}</td>
            <td class="price">${escapeHtml(item.price)}</td>
            <td>${escapeHtml(item.note)}</td>
          </tr>`,
    )
    .join("\n");

  return `<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(data.farmName)}</title>
  <meta name="description" content="${escapeHtml(data.farmDescription.slice(0, 160))}">
  <style>
${SITE_CSS}
  </style>
</head>
<body>

<header class="site-header">
  <div class="header-inner">
    <h1 class="farm-name">${escapeHtml(data.farmName)}</h1>
    <nav>
      <a href="#about">農園について</a>
      <a href="#crops">作物</a>
      ${data.sales.items.length > 0 || data.sales.description ? '<a href="#sales">販売</a>' : ""}
      ${data.sales.contact ? '<a href="#contact">お問い合わせ</a>' : ""}
    </nav>
  </div>
</header>

<main>
  <section id="about" class="section">
    <div class="section-inner">
      <h2>農園について</h2>
      <p class="farm-description">${escapeHtml(data.farmDescription)}</p>
      ${data.farmLocation ? `<p class="farm-meta"><span class="label">所在地</span>${escapeHtml(data.farmLocation)}</p>` : ""}
      ${data.farmPolicy ? `<p class="farm-meta"><span class="label">栽培方針</span>${escapeHtml(data.farmPolicy)}</p>` : ""}
    </div>
  </section>

  <section id="crops" class="section">
    <div class="section-inner">
      <h2>作物紹介</h2>
      <div class="crop-grid">
        ${cropCards}
      </div>
    </div>
  </section>

  ${
    data.sales.items.length > 0 || data.sales.description
      ? `
  <section id="sales" class="section">
    <div class="section-inner">
      <h2>販売情報</h2>
      ${data.sales.description ? `<p>${escapeHtml(data.sales.description)}</p>` : ""}
      ${
        data.sales.items.length > 0
          ? `
      <div class="table-wrap">
        <table>
          <thead>
            <tr><th>商品</th><th>価格</th><th>備考</th></tr>
          </thead>
          <tbody>${salesItems}
          </tbody>
        </table>
      </div>`
          : ""
      }
    </div>
  </section>`
      : ""
  }

  ${
    data.sales.contact
      ? `
  <section id="contact" class="section">
    <div class="section-inner">
      <h2>お問い合わせ</h2>
      <p class="contact">${escapeHtml(data.sales.contact)}</p>
    </div>
  </section>`
      : ""
  }
</main>

<footer>
  <p>&copy; ${new Date().getFullYear()} ${escapeHtml(data.farmName)}</p>
</footer>

</body>
</html>`;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const SITE_CSS = `
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

    .farm-description {
      font-size: 1rem;
      margin-bottom: 1rem;
    }

    .farm-meta {
      font-size: 0.9rem;
      color: var(--color-text-sub);
      margin-bottom: 0.3rem;
    }

    .farm-meta .label {
      display: inline-block;
      min-width: 5em;
      font-weight: 600;
      color: var(--color-text);
    }

    /* 作物グリッド */
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

    .crop-photos {
      display: flex;
      overflow-x: auto;
      scroll-snap-type: x mandatory;
    }

    .crop-photos img {
      width: 100%;
      min-width: 100%;
      height: 220px;
      object-fit: cover;
      scroll-snap-align: start;
    }

    .crop-info {
      padding: 1rem 1.2rem;
    }

    .crop-info h3 {
      font-size: 1.1rem;
      color: var(--color-text);
      margin-bottom: 0.3rem;
    }

    .crop-variety {
      font-size: 0.85rem;
      color: var(--color-text-sub);
      font-style: italic;
      margin-bottom: 0.5rem;
    }

    .crop-info p {
      font-size: 0.9rem;
      color: var(--color-text-sub);
    }

    /* 販売テーブル */
    .table-wrap {
      overflow-x: auto;
      margin-top: 1rem;
    }

    table {
      width: 100%;
      border-collapse: collapse;
    }

    th {
      background: var(--color-accent-light);
      font-weight: 600;
      text-align: left;
      padding: 0.6rem 0.8rem;
      font-size: 0.9rem;
      border-bottom: 2px solid var(--color-border);
    }

    td {
      padding: 0.5rem 0.8rem;
      font-size: 0.9rem;
      border-bottom: 1px solid var(--color-border);
    }

    .price { font-weight: 600; white-space: nowrap; }

    .contact {
      font-size: 1rem;
      white-space: pre-wrap;
    }

    footer {
      text-align: center;
      padding: 2rem;
      font-size: 0.8rem;
      color: var(--color-text-sub);
      border-top: 1px solid var(--color-border);
    }

    @media (max-width: 640px) {
      html { font-size: 15px; }
      .header-inner { flex-direction: column; text-align: center; }
      nav a { margin: 0 0.5rem; }
      .crop-grid { grid-template-columns: 1fr; }
      .section { padding: 2rem 1rem; }
    }
`;
