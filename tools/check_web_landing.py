#!/usr/bin/env python3
"""Check the public landing page's static safety and accessibility contracts.

Uses only the standard library and never contacts a service. This is not a
substitute for the requested viewport, keyboard, contrast, and image review.
Run from any directory: python3 tools/check_web_landing.py
"""

from collections import Counter
from fnmatch import fnmatch
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1] / "public"
ANDROID = "https://play.google.com/store/apps/details?id=com.gotainu.hamster"
LEGAL_ORIGIN = "https://hamster-breeding-app.web.app"
LEGAL_PATHS = {"/terms/", "/privacy/", "/commercial-transactions/", "/support/"}


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.elements = []
        self.ids = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.elements.append((tag, attrs))
        if "id" in attrs:
            self.ids.append(attrs["id"])

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)


def main():
    failures = []
    checks = []

    def check(name, condition, detail=""):
        checks.append((name, bool(condition)))
        if not condition:
            failures.append(name + (": " + detail if detail else ""))

    index = ROOT / "index.html"
    check("landing page exists", index.is_file())
    if not index.is_file():
        print("FAIL: public/index.html is missing")
        return 1
    source = index.read_text(encoding="utf-8")
    page = Page()
    page.feed(source)
    elements = page.elements
    tags = [tag for tag, _ in elements]
    by_tag = lambda name: [attrs for tag, attrs in elements if tag == name]

    check("Japanese document language", any(a.get("lang", "").lower().startswith("ja") for a in by_tag("html")))
    check("mobile viewport without zoom restriction", any(a.get("name") == "viewport" and "width=device-width" in a.get("content", "").replace(" ", "") and not re.search(r"user-scalable\s*=\s*(no|0)|maximum-scale\s*=\s*1(?:\D|$)", a.get("content", ""), re.I) for a in by_tag("meta")))
    check("single main landmark and main heading", tags.count("main") == 1 and tags.count("h1") == 1)
    levels = [int(tag[1]) for tag in tags if re.fullmatch(r"h[1-6]", tag)]
    check("headings do not skip levels", bool(levels) and levels[0] == 1 and all(b <= a + 1 for a, b in zip(levels, levels[1:])))
    check("unique fragment identifiers", all(count == 1 for count in Counter(page.ids).values()))
    check("all images declare alternative text", bool(by_tag("img")) and all("alt" in a for a in by_tag("img")))
    check("no live input, embedded checkout, or executable scripts", not set(tags).intersection({"form", "input", "textarea", "select", "iframe", "script", "object", "embed", "base"}))
    check("no inline event handlers", all(not key.lower().startswith("on") for _, attrs in elements for key in attrs))
    check("no automatic redirect", all(a.get("http-equiv", "").lower() != "refresh" for a in by_tag("meta")))
    check("placeholder buttons are explicitly disabled", bool(by_tag("button")) and all("disabled" in a and a.get("type", "button") == "button" for a in by_tag("button")))
    check("no invented public iOS or internal TestFlight destination", not re.search(r"(?:apps|itunes)\.apple\.com|testflight\.apple\.com", source, re.I))

    hrefs = [a.get("href", "") for a in by_tag("a")]
    check("formal Android store destination", ANDROID in hrefs)
    check("no alternate Android distribution destination", all(h == ANDROID for h in hrefs if "play.google.com/" in h))
    check("all existing legal destinations included", all(LEGAL_ORIGIN + path in hrefs for path in LEGAL_PATHS))
    check("new-window links protect their opener", all({"noopener", "noreferrer"}.issubset(set(a.get("rel", "").split())) for a in by_tag("a") if a.get("target") == "_blank"))
    check("skip link targets the main content", any(a.get("href", "").startswith("#") and a["href"][1:] in {m.get("id") for m in by_tag("main")} for a in by_tag("a")))

    local_files = set()
    stylesheet_files = set()

    def resolve_local(value, base, label):
        parsed = urlsplit(value)
        if parsed.scheme or parsed.netloc:
            check(label + " is locally hosted", False, value)
            return None
        if not parsed.path:
            return None
        path = (ROOT / unquote(parsed.path).lstrip("/") if parsed.path.startswith("/") else base / unquote(parsed.path)).resolve()
        check(label + " stays in public", path.is_relative_to(ROOT.resolve()), value)
        if path.is_dir():
            path /= "index.html"
        check(label + " exists", path.is_file(), value)
        if path.is_file() and path.is_relative_to(ROOT.resolve()):
            local_files.add(path)
            return path
        return None

    for tag, attrs in elements:
        for attr in ("src", "poster"):
            if attr in attrs:
                resolve_local(attrs[attr], ROOT, tag + " " + attr)
        if "srcset" in attrs:
            for candidate in attrs["srcset"].split(","):
                resolve_local(candidate.strip().split()[0], ROOT, tag + " srcset")
        if tag == "link" and "href" in attrs:
            path = resolve_local(attrs["href"], ROOT, "linked resource")
            if path and "stylesheet" in attrs.get("rel", "").split():
                stylesheet_files.add(path)
        if tag == "a":
            href = attrs.get("href", "")
            parsed = urlsplit(href)
            if not href:
                check("links have a destination", False)
            elif parsed.scheme == "https":
                allowed = href == ANDROID or (parsed.netloc == "hamster-breeding-app.web.app" and parsed.path in LEGAL_PATHS and not parsed.query and not parsed.fragment)
                check("external navigation is limited to store and existing legal pages", allowed, href)
            elif parsed.scheme or parsed.netloc:
                check("no login, payment, or unapproved external navigation", False, href)
            elif parsed.path:
                resolve_local(href, ROOT, "local link")
            if not parsed.scheme and not parsed.netloc and not parsed.path and parsed.fragment:
                check("fragment destination exists", unquote(parsed.fragment) in page.ids, href)
            if href == "#":
                check("no misleading empty link action", False)

    css = "\n".join(path.read_text(encoding="utf-8") for path in stylesheet_files)
    check("landing styles are present", bool(css.strip()))
    check("responsive styles are present", bool(re.search(r"@media\b[^{}]*(?:width|orientation)", css)))
    check("visible keyboard focus styling is present", bool(re.search(r":focus(?:-visible)?\b", css)))
    check("reduced-motion preference is handled", "prefers-reduced-motion" in css)
    check("touch target sizing is declared", bool(re.search(r"min-(?:height|block-size)\s*:\s*(?:4[4-9]|[5-9]\d|\d{3,})(?:\.\d+)?px\b", css)))
    for sheet in stylesheet_files:
        text = sheet.read_text(encoding="utf-8")
        for raw in re.findall(r"url\(\s*['\"]?([^'\")\s]+)", text):
            resolve_local(raw, sheet.parent, "stylesheet asset")
        check("no external stylesheet imports", not re.search(r"@import\b", text))

    text_files = [index, *stylesheet_files]
    check("no secret key material in landing source", not any(re.search(r"\b(?:sk_(?:live|test)_[A-Za-z0-9]{12,}|whsec_[A-Za-z0-9]{12,}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----)", path.read_text(encoding="utf-8")) for path in text_files))

    preview_file = ROOT.parent / "firebase.preview.json"
    try:
        preview = json.loads(preview_file.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        check("Preview configuration is readable JSON", False, str(error))
        preview = {}
    check("Preview configuration includes Hosting only", set(preview) == {"hosting"})
    hosting = preview.get("hosting", {})
    if not isinstance(hosting, dict):
        check("Preview uses one Hosting site", False)
        hosting = {}
    check("Preview reuses the existing site and public directory", hosting.get("site") == "hamster-breeding-app" and hosting.get("public") == "public")
    check("Preview does not add server routes or deploy hooks", not any(hosting.get(key) for key in ("rewrites", "redirects", "predeploy", "postdeploy")))
    headers = {header.get("key", "").lower(): header.get("value", "") for rule in hosting.get("headers", []) if rule.get("source") == "**" for header in rule.get("headers", [])}
    csp = {parts[0]: parts[1:] for directive in headers.get("content-security-policy", "").split(";") if (parts := directive.split())}
    check("Preview forbids connections and form submission", all(csp.get(directive) == ["'none'"] for directive in ("default-src", "connect-src", "form-action")))
    check("Preview forbids scripts, base overrides, and framing", csp.get("script-src", csp.get("default-src")) == ["'none'"] and all(csp.get(directive) == ["'none'"] for directive in ("base-uri", "frame-ancestors")))
    check("Preview suppresses indexing and referrer disclosure", {"noindex", "nofollow", "noarchive"}.issubset({part.strip().lower() for part in headers.get("x-robots-tag", "").split(",")}) and headers.get("referrer-policy") == "no-referrer")
    check("Preview disables MIME sniffing", headers.get("x-content-type-options") == "nosniff")
    ignored = lambda relative: any(fnmatch(relative, pattern) for pattern in hosting.get("ignore", []))
    excluded = ("billing/success/index.html", "billing/cancel/index.html", "billing/portal-return/index.html", "account-deletion/index.html", "terms/index.html", "privacy/index.html", "commercial-transactions/index.html", "support/index.html", "assets/legal.css", "assets/landing/provenance.json")
    check("Preview excludes legacy billing, legal, and private provenance pages", all(ignored(path) for path in excluded))
    check("Preview retains the local font and its license", all(path.is_file() and not ignored(path.relative_to(ROOT).as_posix()) for path in (ROOT / "assets/landing/Caveat-Bold.ttf", ROOT / "assets/landing/OFL.txt")))

    print(f"Static checks: {sum(ok for _, ok in checks)}/{len(checks)} passed; {len(local_files)} local resources resolved.")
    for failure in failures:
        print("FAIL: " + failure)
    print("Manual/render review still required: 360/390/768/desktop layout, actual 44px hit areas, keyboard order, contrast, cropping, claims, and screenshot provenance.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
