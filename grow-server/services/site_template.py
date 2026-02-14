"""農家ホームページの HTML テンプレート生成

栽培記録データから静的 HTML を生成する。外部依存なし。
いいね機能・消費者登録 UI 付き。
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
    farm_username: str = "",
    api_base_url: str = "",
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
    has_like = bool(farm_username and api_base_url)
    year = datetime.now().year

    like_html = _like_section(_e(farm_username)) if has_like else ""
    modal_html = _auth_modal_html() if has_like else ""
    script_html = _like_script(_e(api_base_url), _e(farm_username)) if has_like else ""

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
      {like_html}
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
  <p class="powered-by">Powered by <a href="https://cowork.aiseed.dev" target="_blank">Grow</a></p>
</footer>

{modal_html}
{script_html}

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


def _like_section(farm_username: str) -> str:
    return f"""
      <div class="like-section" id="likeSection">
        <button class="like-btn" id="likeBtn" onclick="toggleLike()" title="応援する">
          <svg id="likeIcon" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
          </svg>
          <span id="likeLabel">応援する</span>
          <span class="like-count" id="likeCount">0</span>
        </button>
        <p class="like-hint" id="likeHint"></p>
      </div>"""


def _auth_modal_html() -> str:
    return """
<!-- 認証モーダル -->
<div class="modal-overlay" id="authModal" style="display:none;">
  <div class="modal-content">
    <button class="modal-close" onclick="closeModal()">&times;</button>
    <h3 id="authTitle">新規登録</h3>
    <p class="auth-subtitle" id="authSubtitle">農園を応援するにはアカウント登録が必要です</p>
    <form id="authForm" onsubmit="handleAuth(event)">
      <div class="form-group">
        <label for="authEmail">メールアドレス</label>
        <input type="email" id="authEmail" required placeholder="email@example.com">
      </div>
      <div class="form-group">
        <label for="authPassword">パスワード</label>
        <input type="password" id="authPassword" required minlength="6" placeholder="6文字以上">
      </div>
      <div class="form-group" id="nameGroup">
        <label for="authName">表示名（任意）</label>
        <input type="text" id="authName" placeholder="表示名">
      </div>
      <p class="auth-error" id="authError" style="display:none;"></p>
      <button type="submit" class="auth-submit" id="authSubmit">登録する</button>
    </form>
    <p class="auth-switch">
      <span id="authSwitchText">すでにアカウントをお持ちの方</span>
      <a href="#" onclick="switchAuthMode(event)" id="authSwitchLink">ログイン</a>
    </p>
  </div>
</div>"""


def _like_script(api_base_url: str, farm_username: str) -> str:
    # JavaScript は f-string を使わず、テンプレートリテラルで埋め込む
    return f"""
<script>
(function() {{
  var API = '{api_base_url}';
  var FARM = '{farm_username}';
  var TOKEN_KEY = 'grow_consumer_token';
  var MODE = 'register'; // or 'login'

  function getToken() {{ return localStorage.getItem(TOKEN_KEY); }}
  function setToken(t) {{ localStorage.setItem(TOKEN_KEY, t); }}
  function clearToken() {{ localStorage.removeItem(TOKEN_KEY); }}

  function headers() {{
    var h = {{'Content-Type': 'application/json'}};
    var t = getToken();
    if (t) h['Authorization'] = 'Bearer ' + t;
    return h;
  }}

  // いいね状態を読み込む
  function loadLikes() {{
    fetch(API + '/consumer/likes/' + FARM, {{
      headers: headers()
    }})
    .then(function(r) {{ return r.json(); }})
    .then(function(data) {{
      updateLikeUI(data.liked, data.count);
    }})
    .catch(function() {{}});
  }}

  function updateLikeUI(liked, count) {{
    var icon = document.getElementById('likeIcon');
    var label = document.getElementById('likeLabel');
    var countEl = document.getElementById('likeCount');
    var btn = document.getElementById('likeBtn');

    countEl.textContent = count;

    if (liked) {{
      icon.setAttribute('fill', '#e25555');
      icon.setAttribute('stroke', '#e25555');
      label.textContent = '応援中';
      btn.classList.add('liked');
    }} else {{
      icon.setAttribute('fill', 'none');
      icon.setAttribute('stroke', 'currentColor');
      label.textContent = '応援する';
      btn.classList.remove('liked');
    }}
  }}

  // いいねトグル
  window.toggleLike = function() {{
    if (!getToken()) {{
      openModal();
      return;
    }}

    fetch(API + '/consumer/like/' + FARM, {{
      method: 'POST',
      headers: headers()
    }})
    .then(function(r) {{
      if (r.status === 401) {{
        clearToken();
        openModal();
        return null;
      }}
      return r.json();
    }})
    .then(function(data) {{
      if (data) updateLikeUI(data.liked, data.count);
    }})
    .catch(function() {{}});
  }};

  // モーダル操作
  function openModal() {{
    MODE = 'register';
    updateModalUI();
    document.getElementById('authModal').style.display = 'flex';
    document.getElementById('authError').style.display = 'none';
  }}

  window.closeModal = function() {{
    document.getElementById('authModal').style.display = 'none';
  }};

  window.switchAuthMode = function(e) {{
    e.preventDefault();
    MODE = MODE === 'register' ? 'login' : 'register';
    updateModalUI();
    document.getElementById('authError').style.display = 'none';
  }};

  function updateModalUI() {{
    var title = document.getElementById('authTitle');
    var subtitle = document.getElementById('authSubtitle');
    var nameGroup = document.getElementById('nameGroup');
    var submit = document.getElementById('authSubmit');
    var switchText = document.getElementById('authSwitchText');
    var switchLink = document.getElementById('authSwitchLink');

    if (MODE === 'register') {{
      title.textContent = '新規登録';
      subtitle.textContent = '農園を応援するにはアカウント登録が必要です';
      nameGroup.style.display = 'block';
      submit.textContent = '登録する';
      switchText.textContent = 'すでにアカウントをお持ちの方';
      switchLink.textContent = 'ログイン';
    }} else {{
      title.textContent = 'ログイン';
      subtitle.textContent = 'アカウントにログイン';
      nameGroup.style.display = 'none';
      submit.textContent = 'ログイン';
      switchText.textContent = 'アカウントをお持ちでない方';
      switchLink.textContent = '新規登録';
    }}
  }}

  // 登録 / ログイン処理
  window.handleAuth = function(e) {{
    e.preventDefault();
    var email = document.getElementById('authEmail').value;
    var password = document.getElementById('authPassword').value;
    var errorEl = document.getElementById('authError');
    var submitBtn = document.getElementById('authSubmit');

    submitBtn.disabled = true;
    errorEl.style.display = 'none';

    var url = API + '/consumer/' + MODE;
    var body = {{ email: email, password: password }};
    if (MODE === 'register') {{
      body.display_name = document.getElementById('authName').value || '';
    }}

    fetch(url, {{
      method: 'POST',
      headers: {{'Content-Type': 'application/json'}},
      body: JSON.stringify(body)
    }})
    .then(function(r) {{
      if (!r.ok) return r.json().then(function(d) {{ throw new Error(d.detail || 'エラーが発生しました'); }});
      return r.json();
    }})
    .then(function(data) {{
      setToken(data.access_token);
      closeModal();
      // 自動的にいいねする
      toggleLike();
    }})
    .catch(function(err) {{
      errorEl.textContent = err.message;
      errorEl.style.display = 'block';
    }})
    .finally(function() {{
      submitBtn.disabled = false;
    }});
  }};

  // ページ読み込み時にいいね状態を取得
  loadLikes();
}})();
</script>"""


SITE_CSS = """\
    :root {
      --color-bg: #faf9f6;
      --color-surface: #ffffff;
      --color-text: #2c2c2c;
      --color-text-sub: #5a5a5a;
      --color-accent: #4a7c59;
      --color-accent-light: #e8f0eb;
      --color-border: #e0ddd8;
      --color-like: #e25555;
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

    /* いいねセクション */
    .like-section {
      margin-top: 1.5rem;
      padding-top: 1rem;
      border-top: 1px solid var(--color-border);
    }

    .like-btn {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.6rem 1.2rem;
      border: 2px solid var(--color-border);
      border-radius: 2rem;
      background: var(--color-surface);
      color: var(--color-text-sub);
      font-size: 0.95rem;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .like-btn:hover {
      border-color: var(--color-like);
      color: var(--color-like);
    }
    .like-btn.liked {
      border-color: var(--color-like);
      color: var(--color-like);
      background: #fff5f5;
    }
    .like-count {
      font-weight: 700;
      min-width: 1.5em;
      text-align: center;
    }
    .like-hint {
      font-size: 0.8rem;
      color: var(--color-text-sub);
      margin-top: 0.4rem;
    }

    /* 認証モーダル */
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.4);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
    }
    .modal-content {
      background: var(--color-surface);
      border-radius: 12px;
      padding: 2rem;
      width: 90%;
      max-width: 400px;
      position: relative;
      box-shadow: 0 8px 32px rgba(0,0,0,0.15);
    }
    .modal-close {
      position: absolute;
      top: 0.8rem; right: 1rem;
      background: none; border: none;
      font-size: 1.5rem; color: var(--color-text-sub);
      cursor: pointer;
    }
    .modal-content h3 {
      font-size: 1.2rem;
      color: var(--color-accent);
      margin-bottom: 0.3rem;
    }
    .auth-subtitle {
      font-size: 0.85rem;
      color: var(--color-text-sub);
      margin-bottom: 1.2rem;
    }
    .form-group {
      margin-bottom: 1rem;
    }
    .form-group label {
      display: block;
      font-size: 0.85rem;
      font-weight: 600;
      margin-bottom: 0.3rem;
      color: var(--color-text);
    }
    .form-group input {
      width: 100%;
      padding: 0.6rem 0.8rem;
      border: 1px solid var(--color-border);
      border-radius: 6px;
      font-size: 0.95rem;
      font-family: inherit;
    }
    .form-group input:focus {
      outline: none;
      border-color: var(--color-accent);
      box-shadow: 0 0 0 2px var(--color-accent-light);
    }
    .auth-error {
      color: var(--color-like);
      font-size: 0.85rem;
      margin-bottom: 0.8rem;
    }
    .auth-submit {
      width: 100%;
      padding: 0.7rem;
      background: var(--color-accent);
      color: #fff;
      border: none;
      border-radius: 6px;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }
    .auth-submit:hover { background: #3d6a4b; }
    .auth-submit:disabled { opacity: 0.6; cursor: not-allowed; }
    .auth-switch {
      text-align: center;
      margin-top: 1rem;
      font-size: 0.85rem;
      color: var(--color-text-sub);
    }
    .auth-switch a {
      color: var(--color-accent);
      text-decoration: none;
      font-weight: 600;
      margin-left: 0.3rem;
    }

    .powered-by { margin-top: 0.3rem; font-size: 0.75rem; }
    .powered-by a { color: var(--color-accent); text-decoration: none; }

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
