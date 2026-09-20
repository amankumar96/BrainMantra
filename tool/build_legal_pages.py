"""Builds docs/*.html (the public legal pages) from Documents/*.md.

Run from the repo root:   python tool/build_legal_pages.py
The Markdown files are the single source of truth - edit those, then re-run
this script, then re-publish the docs/ folder (see
Documents/FOUNDER_LAUNCH_GUIDE.md, "Publish your legal pages").
Handles only the tiny Markdown subset the legal docs use: # / ## headings,
paragraphs, - bullets, 1. numbered lists, **bold**, [text](url) and bare URLs.
"""
import html, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGES = {
    "privacy.html": ("Documents/PRIVACY_POLICY.md", "Privacy Policy"),
    "terms.html": ("Documents/TERMS_OF_SERVICE.md", "Terms of Service"),
    "delete-account.html": ("Documents/DELETE_ACCOUNT_PAGE.md", "Delete Your Account"),
}

CSS = """
body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;line-height:1.6;
max-width:720px;margin:0 auto;padding:24px 16px;color:#1a2233;background:#f7fafd}
h1{color:#3d6ff5;font-size:1.7rem}h2{margin-top:1.8em;font-size:1.2rem;color:#2a3a6a}
a{color:#3d6ff5}ul,ol{padding-left:1.4em}nav{margin-bottom:1.5em;font-size:.9rem}
footer{margin-top:3em;font-size:.85rem;color:#667}
"""

def inline(t):
    t = html.escape(t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"`(.+?)`", r"<code>\1</code>", t)
    t = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', t)
    t = re.sub(r'(?<!href=")(https?://[^\s<)]+)', r'<a href="\1">\1</a>', t)
    return t

def convert(md):
    out, para, lst = [], [], None
    def flush_p():
        if para:
            out.append("<p>" + " ".join(inline(x) for x in para) + "</p>")
            para.clear()
    def close_l():
        nonlocal lst
        if lst:
            out.append(f"</{lst}>")
            lst = None
    for line in md.splitlines():
        s = line.strip()
        if not s:
            flush_p(); close_l(); continue
        m = re.match(r"^(#{1,2}) (.+)", s)
        if m:
            flush_p(); close_l()
            lvl = len(m.group(1))
            out.append(f"<h{lvl}>{inline(m.group(2))}</h{lvl}>"); continue
        b = re.match(r"^- (.+)", s); n = re.match(r"^\d+\. (.+)", s)
        if b or n:
            flush_p()
            tag = "ul" if b else "ol"
            if lst != tag:
                close_l(); out.append(f"<{tag}>"); lst = tag
            out.append("<li>" + inline((b or n).group(1)) + "</li>"); continue
        close_l(); para.append(s)
    flush_p(); close_l()
    return "\n".join(out)

def page(title, body):
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Brain Mantra - {title}</title><style>{CSS}</style></head><body>
<nav><a href="index.html">Home</a> · <a href="privacy.html">Privacy Policy</a> ·
<a href="terms.html">Terms of Service</a> · <a href="delete-account.html">Delete Account</a></nav>
{body}
<footer>Brain Mantra: Maths and IQ Reasoning</footer></body></html>
"""

docs = ROOT / "docs"
docs.mkdir(exist_ok=True)
for name, (src, title) in PAGES.items():
    body = convert((ROOT / src).read_text(encoding="utf-8"))
    (docs / name).write_text(page(title, body), encoding="utf-8")
    print("wrote", docs / name)

index_body = """<h1>Brain Mantra</h1>
<p>A maths and IQ reasoning quiz game for Android.</p>
<ul><li><a href="privacy.html">Privacy Policy</a></li>
<li><a href="terms.html">Terms of Service</a></li>
<li><a href="delete-account.html">How to delete your account and data</a></li></ul>"""
(docs / "index.html").write_text(page("Home", index_body), encoding="utf-8")
print("wrote", docs / "index.html")
