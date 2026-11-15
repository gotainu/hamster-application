#!/usr/bin/env python3
"""Offline brand checks; contrast arithmetic is not a browser AA audit.

The d969c19 baseline guards original functional controls. Task7 adds a gated
Apple provider surface; its API and data boundaries are checked separately.
Task 3 replaced the pending plan panel; Task 4 adds an isolated Test Checkout.
Payment runtime/security checks live in check_web_account.py. Emulator and
browser tests remain separate.
"""
from collections import Counter
from hashlib import sha256
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import subprocess
import sys
from urllib.parse import urlparse

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / 'public'
ASSETS = PUBLIC / 'assets/landing'
BASE = 'd969c1955e2861a8eea4a3a4b5a101561532b7b3'
PLAN_BASE = '57e625c5451a617caeaa5670e22740c135187994'
CHECKOUT_BASE = '98f3fb8a6cd8a3fdcee91149ea3a72f2fe404b9a'
PREVIEW = 'https://hamster-breeding-app--web-first-task1-lco08m60.web.app'
CATCHPHRASE = 'うちの子と、もっと健康で幸せに'
ICON_SOURCE = 'store_assets/icons/hamster_pencil_mark_master.png'


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.nodes = []
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        self.nodes.append((tag, dict(attrs)))


def baseline(path, revision=BASE):
    return subprocess.check_output(['git', 'show', f'{revision}:{path}'], cwd=ROOT)


def split_selectors(value):
    start, depth = 0, 0
    for index, char in enumerate(value):
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
        elif char == ',' and depth == 0:
            yield value[start:index].strip()
            start = index + 1
    yield value[start:].strip()


def css_rules(source, scopes=()):
    """Read the project's flat CSS declarations, retaining conditional scopes."""
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    position = 0
    while position < len(source):
        opening = source.find('{', position)
        if opening < 0:
            break
        heading = source[position:opening].strip()
        depth, closing, quote = 1, opening + 1, None
        while closing < len(source) and depth:
            char = source[closing]
            if quote:
                if char == quote and source[closing - 1] != '\\':
                    quote = None
            elif char in "\"'":
                quote = char
            elif char == '{':
                depth += 1
            elif char == '}':
                depth -= 1
            closing += 1
        if depth:
            raise ValueError('Unbalanced CSS braces')
        body = source[opening + 1:closing - 1]
        if heading.startswith('@') and heading != '@font-face':
            yield from css_rules(body, scopes + (heading,))
        else:
            declarations = dict(
                (key.strip(), value.strip())
                for item in body.split(';') if ':' in item
                for key, value in [item.split(':', 1)]
            )
            for selector in split_selectors(heading):
                yield selector, declarations, scopes
        position = closing


def blend(front, back):
    return tuple(front[index] * front[3] + back[index] * (1 - front[3]) for index in range(3)) + (1.,)


def luminance(color):
    channels = [channel / 255 for channel in color[:3]]
    linear = [channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055) ** 2.4 for channel in channels]
    return sum(channel * weight for channel, weight in zip(linear, (.2126, .7152, .0722)))


def contrast(front, back):
    front = blend(front, back)
    light, dark = sorted((luminance(front), luminance(back)), reverse=True)
    return (light + .05) / (dark + .05)


def main():
    checks, ratios = [], []

    def check(name, condition):
        checks.append((name, bool(condition)))

    sources = {name: (PUBLIC / 'assets' / name).read_text() for name in ('landing.css', 'brand.css', 'account.css', 'plan.css', 'checkout.css')}
    rules = {name: list(css_rules(source)) for name, source in sources.items()}
    tokens = {}
    for name in ('landing.css', 'brand.css'):
        for selector, declarations, scopes in rules[name]:
            if selector == ':root' and not scopes:
                tokens.update({key: value for key, value in declarations.items() if key.startswith('--')})

    def resolve(value):
        for _ in range(12):
            new = re.sub(r'var\((--[\w-]+)(?:\s*,\s*([^()]+))?\)', lambda match: tokens.get(match[1], match[2] or ''), value)
            if new == value:
                return value
            value = new
        raise ValueError('CSS variable cycle')

    def declaration(file, selector, prop, supported=False):
        values = []
        for current, declarations, scopes in rules[file]:
            allowed = not scopes or (supported and all(scope.startswith('@supports') for scope in scopes))
            if current == selector and allowed and prop in declarations:
                values.append(declarations[prop])
        if not values:
            raise ValueError(f'Missing actual CSS declaration: {file} {selector} {prop}')
        return resolve(values[-1])

    def color(value):
        value = resolve(value.strip()).lower()
        if value in ('white', 'black'):
            value = '#ffffff' if value == 'white' else '#000000'
        if value.startswith('#'):
            digits = value[1:]
            if len(digits) == 3:
                digits = ''.join(char * 2 for char in digits)
            if len(digits) != 6:
                raise ValueError('Expected six-digit CSS color')
            return tuple(int(digits[index:index + 2], 16) for index in (0, 2, 4)) + (1.,)
        match = re.fullmatch(r'rgba?\(([^)]+)\)', value)
        if match:
            parts = [float(part.strip()) for part in match[1].split(',')]
            if len(parts) == 3:
                parts.append(1.)
            if len(parts) == 4:
                return tuple(parts)
        raise ValueError('Unsupported CSS color: ' + value)

    def ratio(name, foreground, background, minimum=4.5):
        value = contrast(foreground, background)
        ratios.append((name, value, minimum))
        check(f'contrast {name} >= {minimum}:1', value >= minimum)

    manifest = json.loads((ASSETS / 'provenance.json').read_text())
    entries = {entry['file']: entry for entry in manifest['assets']}
    for filename, entry in entries.items():
        path = ASSETS / filename
        check('provenance output SHA ' + filename, path.is_file() and sha256(path.read_bytes()).hexdigest() == entry['output_sha256'])
        if 'width' in entry:
            with Image.open(path) as image:
                check('provenance image geometry ' + filename, image.size == (entry['width'], entry['height']) and image.mode == entry['mode'])
        source = ROOT / entry['source']
        if source.is_file():
            check('provenance source SHA ' + filename, sha256(source.read_bytes()).hexdigest() == entry['source_sha256'])
        elif entry.get('source_sha256'):
            check('unbundled source fingerprint ' + filename, re.fullmatch(r'[0-9a-f]{64}', entry['source_sha256']) is not None)

    # The owner's latest clarification selects the native pencil-outline
    # identity. Versioned file names also avoid reusing the rejected image URLs.
    master = Image.open(ROOT / ICON_SOURCE).convert('RGB')
    check('current outline master unchanged', (ROOT / ICON_SOURCE).read_bytes() == baseline(ICON_SOURCE))
    check('native outline source is the same app/store image', (ROOT / 'store_assets/icons/app_store_icon_1024.png').read_bytes() == (ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png').read_bytes())
    for filename, side in [('hamcare-mark-outline.png', 256), ('favicon-outline-32.png', 32), ('apple-touch-icon-outline.png', 180)]:
        image = Image.open(ASSETS / filename).convert('RGB')
        expected = master.resize((side, side), Image.Resampling.LANCZOS)
        check('outline icon derives from current native master ' + filename, entries[filename]['source'] == ICON_SOURCE and image.size == (side, side) and image.tobytes() == expected.tobytes())
    og_image = Image.open(ASSETS / 'og-hamcare-outline.png')
    check('outline OG dimensions and format', og_image.size == (1200, 630) and og_image.format == 'PNG')
    rejected = {'hamcare-mark.png', 'favicon-32.png', 'apple-touch-icon.png', 'og-hamcare.jpg'}
    check('rejected white-hamster derivatives are not public', all(not (ASSETS / name).exists() and name not in entries for name in rejected))
    home = entries['home-screen.jpg']
    crop = re.search(r'Crop\s*\[([\d, ]+)\]', home['notes'])
    rectangle = [int(value) for value in crop[1].split(',')] if crop else []
    check('Home is documented actual source with OS-only crop', home['source'] == 'user-provided/1000017308.jpg' and rectangle == [0, 54, 591, 1202] and (home['width'], home['height']) == (rectangle[2] - rectangle[0], rectangle[3] - rectangle[1]))
    check('Home original retained outside repository', manifest['privacy_review']['source_files_modified'] is False and manifest['privacy_review']['app_capture_or_rebuild'] is False)

    for path in ('public/index.html', 'public/account/index.html'):
        html = (ROOT / path).read_text()
        page = Page(html)
        old = Page(baseline(path).decode())
        meta = {attrs.get('property', attrs.get('name')): attrs.get('content') for tag, attrs in page.nodes if tag == 'meta'}
        links = {attrs.get('rel'): attrs for tag, attrs in page.nodes if tag == 'link'}
        check(path + ' shared theme', any(tag == 'link' and attrs.get('href') == '/assets/brand.css' for tag, attrs in page.nodes))
        check(path + ' metadata', all(meta.get(key) for key in ('description', 'og:title', 'og:description', 'og:image:alt', 'twitter:title', 'twitter:description', 'twitter:image:alt')))
        check(path + ' shared OG/Twitter', meta.get('og:image') == meta.get('twitter:image') == PREVIEW + '/assets/landing/og-hamcare-outline.png' and meta.get('twitter:card') == 'summary_large_image')
        check(path + ' icon links', links.get('icon', {}).get('href') == '/assets/landing/favicon-outline-32.png' and links.get('apple-touch-icon', {}).get('href') == '/assets/landing/apple-touch-icon-outline.png')
        check(path + ' shared header identity', 'class="brand-tagline">' + CATCHPHRASE in html and any(tag == 'img' and attrs.get('src') == '/assets/landing/hamcare-mark-outline.png' and all(word in attrs.get('alt', '') for word in ('黒', '白', '輪郭')) for tag, attrs in page.nodes))
        check(path + ' outline metadata description', all('輪郭' in meta.get(key, '') and 'シアン' not in meta.get(key, '') for key in ('og:image:alt', 'twitter:image:alt')))
        check(path + ' rejected image URLs absent', all('/assets/landing/' + name not in html for name in rejected))
        check(path + ' alt for every image', all('alt' in attrs for tag, attrs in page.nodes if tag == 'img'))
        decorative = {'/assets/landing/google-g.png', '/assets/landing/avatar-roborovski.png'}
        check(path + ' empty alt only for intentional decoration', all(attrs['src'] in decorative for tag, attrs in page.nodes if tag == 'img' and attrs.get('alt') == ''))
        check(path + ' local evidenced images only', all(attrs.get('src', '').startswith('/assets/landing/') and attrs.get('src', '').rsplit('/', 1)[-1] in entries for tag, attrs in page.nodes if tag == 'img'))
        ids = {attrs['id'] for _, attrs in page.nodes if 'id' in attrs}
        old_ids = {attrs['id'] for _, attrs in old.nodes if 'id' in attrs}
        permitted_replacements = {'pending-panel', 'pending-title'} if path.endswith('account/index.html') else set()
        check(path + ' existing feature and Auth IDs retained except replaced pending panel', old_ids - ids == permitted_replacements)
        destinations = Counter(attrs.get('href') for tag, attrs in page.nodes if tag == 'a')
        old_destinations = Counter(attrs.get('href') for tag, attrs in old.nodes if tag == 'a')
        check(path + ' existing navigation and legal destinations retained', not (old_destinations - destinations))
        check(path + ' accessible references resolve', all(value in ids for _, attrs in page.nodes for name in ('for', 'aria-controls', 'aria-labelledby', 'aria-describedby') if name in attrs for value in attrs[name].split()))
        check(path + ' zoom not suppressed', 'user-scalable=no' not in html and 'maximum-scale=1' not in html)
        if path.endswith('account/index.html'):
            # New plan and Stripe Test controls are outside Auth. Guard original
            # form/control and associated label without freezing the new panel.
            controls = {'form', 'input', 'button', 'fieldset', 'label'}
            existing_control_ids = {attrs['id'] for tag, attrs in old.nodes if tag in controls and 'id' in attrs}
            signature = lambda tree: [(tag, {key: value for key, value in attrs.items() if key != 'class'}) for tag, attrs in tree.nodes if tag in controls and (attrs.get('id') in existing_control_ids or attrs.get('for') in existing_control_ids)]
            check('Auth form behavior attributes unchanged', signature(page) == signature(old))
            form = lambda value: re.search(r'<form\b[^>]*\bid="email-form"[^>]*>.*?</form>', value, re.S)[0]
            check('Auth form markup unchanged for Checkout', form(html) == form(baseline(path, CHECKOUT_BASE).decode()))
            check('error live region retained', any(attrs.get('role') == 'alert' for _, attrs in page.nodes) and any(attrs.get('aria-live') == 'polite' for _, attrs in page.nodes))
        else:
            feature_images = [attrs['src'] for tag, attrs in page.nodes if tag == 'img' and attrs.get('src', '').rsplit('/', 1)[-1].startswith('screen-')]
            check('four actual feature screenshots retained', set(feature_images) == {'/assets/landing/screen-' + item + '.png' for item in ('record', 'changes', 'ai', 'environment')})
            check('actual Home with visible example note', 'class="home-screen"' in html and '実際のHome画面例' in html and 'テスト用プロフィール' in html)

    path='public/assets/firebase-web-config.mjs'
    check('original Firebase config unchanged', (ROOT/path).read_bytes()==baseline(path))
    auth_service=(PUBLIC/'assets/account-service.mjs').read_text()
    auth_entry=(PUBLIC/'assets/account.mjs').read_text()
    check('Apple addition retains explicit disabled capability and SDK Popup','appleSignInEnabled = false' in auth_service and 'appleSignInEnabled: false' in auth_entry and "new sdk.OAuthProvider('apple.com')" in auth_service and 'sdk.signInWithPopup(auth, provider)' in auth_service)
    for path in ['public/index.html', 'public/assets/landing.css', 'public/assets/brand.css', 'public/assets/plan.css']:
        check('existing brand unchanged for Checkout ' + path, (ROOT / path).read_bytes() == baseline(path, CHECKOUT_BASE))
    account_css=(PUBLIC/'assets/account.css').read_text()
    check('existing account brand unchanged except appended official Apple button',account_css.split('\n/* Official Apple full-button PNG, displayed without redrawing or recoloring. */',1)[0].encode()==baseline('public/assets/account.css',CHECKOUT_BASE))
    apple=entries.get('apple-sign-in-ja.png',{})
    apple_image=ASSETS/'apple-sign-in-ja.png'
    check('Apple full button is the unchanged official ja_JP PNG',apple.get('source','').startswith('https://appleid.cdn-apple.com/appleid/button?') and 'locale=ja_JP' in apple.get('source','') and apple.get('source_sha256')==apple.get('output_sha256')=='d89d74eefcf88d09c3207351cef5290dedc2e2d71f08c8bf45a6b41e7d88d25a' and sha256(apple_image.read_bytes()).hexdigest()==apple['source_sha256'])
    check('Apple graphic preserves official size and accessible wording',apple.get('width')==780 and apple.get('height')==162 and 'alt="Appleでサインイン"' in (PUBLIC/'account/index.html').read_text())
    check('Apple touch target stays 54px and graphic retains aspect ratio','width: 100%; min-height: 54px' in account_css and 'width: min(100%, 260px); height: auto' in account_css)
    presentation_code = '\n'.join((PUBLIC / 'assets' / name).read_text() for name in ('account-model.mjs', 'account-view.mjs', 'plan-model.mjs', 'checkout-model.mjs', 'checkout-view.mjs'))
    check('presentation has no business writer, custom storage or direct payment transport', not re.search(r'\b(?:setDoc|updateDoc|addDoc|deleteDoc|writeBatch|runTransaction|httpsCallable|fetch|fetchRequest)\s*\(|localStorage|sessionStorage|\.innerHTML|insertAdjacentHTML|api\.stripe|cloudfunctions\.net|run\.app', presentation_code))
    for filename in ('screen-record.png', 'screen-changes.png', 'screen-ai.png', 'screen-environment.png'):
        check('real screenshot unchanged ' + filename, (ASSETS / filename).read_bytes() == baseline('public/assets/landing/' + filename))

    for name, source in sources.items():
        # Checkout reuses the original .account-card input/.button focus styles.
        focus_source = source + sources['account.css'] if name == 'checkout.css' else source
        check(name + ' motion/contrast fallback', all(value in source for value in ('prefers-reduced-motion', 'forced-colors')) and 'focus-visible' in focus_source)
    check('glass has prefixed and unprefixed conditional support', all(value in sources['brand.css'] + sources['account.css'] for value in ('@supports', '-webkit-backdrop-filter', 'backdrop-filter')))
    check('solid fallback before glass', declaration('account.css', '.account-card', 'background').startswith('#') and declaration('account.css', '#account-panel', 'background').startswith('#'))
    for file, selector in [('landing.css', '.button'), ('landing.css', '.site-header nav a'), ('landing.css', '.text-link'), ('account.css', '.quiet-button'), ('account.css', '.account-card input'), ('account.css', '.password-toggle')]:
        value = declaration(file, selector, 'min-height')
        check('44px target declaration ' + selector, value.endswith('px') and float(value[:-2]) >= 44)

    white = color('#fff')
    background = declaration('brand.css', 'body::before', 'background')
    overlay_colors = re.findall(r'rgba\([^)]*\)', background)
    overlays = [color(value) for value in overlay_colors]
    check('real habitat background has dark overlay', bool(overlays) and '/assets/landing/habitat-night.webp' in background)
    body_worst = max((blend(value, white) for value in overlays), key=luminance)
    hero_background = declaration('landing.css', '.hero::before', 'background')
    hero_overlays = [color(value) for value in re.findall(r'rgba\([^)]*\)', hero_background)]
    check('actual hero background has dark overlay', bool(hero_overlays) and '/assets/landing/habitat-night.webp' in hero_background)
    hero_worst = max((blend(value, white) for value in hero_overlays), key=luminance)
    glass_worst = blend(color(tokens['--hamcare-glass']), white)
    strong_worst = blend(color(tokens['--hamcare-glass-strong']), white)
    primary, secondary, mint = (color(tokens[key]) for key in ('--hamcare-text-primary', '--hamcare-text-secondary', '--hamcare-accent-mint'))
    for label, surface in [('image/overlay (white-source worst case)', body_worst), ('hero image/overlay (white-source worst case)', hero_worst), ('glass (white-source worst case)', glass_worst), ('strong glass (white-source worst case)', strong_worst)]:
        ratio(label + ' primary', primary, surface)
        ratio(label + ' secondary', secondary, surface)
        ratio(label + ' link', mint, surface)
        ratio(label + ' focus', color(tokens['--hamcare-accent-cyan']), surface, 3)
    for file, selector in [('landing.css', '.button.primary'), ('account.css', '.account-shell .button.primary'), ('account.css', '.account-shell .google-button'), ('account.css', '.account-card input'), ('account.css', '.auth-alert')]:
        foreground = color(declaration(file, selector, 'color'))
        surface = color(declaration(file, selector, 'background'))
        ratio(file + ' ' + selector + ' text', foreground, surface)
    for file, selector in [('landing.css', '.button.primary'), ('account.css', '.account-shell .button.primary')]:
        fill = color(declaration(file, selector, 'background'))
        try:
            border = declaration(file, selector, 'border-color')
        except ValueError:
            border = declaration(file, selector, 'border')
        match = re.search(r'rgba?\([^)]*\)|#[0-9a-fA-F]{3,6}\b', border)
        boundary = blend(color(match[0]), fill)
        ratio(file + ' Primary boundary outside', boundary, glass_worst, 3)
    input_bg = color(declaration('account.css', '.account-card input', 'background'))
    input_border = re.search(r'#[0-9a-fA-F]{3,6}\b', declaration('account.css', '.account-card input', 'border'))[0]
    ratio('input boundary inside', color(input_border), input_bg, 3)
    ratio('input boundary outside', color(input_border), glass_worst, 3)
    ratio('invalid input boundary', color(tokens['--hamcare-danger']), input_bg, 3)
    google_border = re.search(r'#[0-9a-fA-F]{3,6}\b', declaration('account.css', '.account-shell .google-button', 'border'))[0]
    ratio('Google button boundary inside', color(google_border), white, 3)
    ratio('Google button boundary outside', color(google_border), glass_worst, 3)
    plan_surface = color(declaration('plan.css', '.plan-section', 'background'))
    plan_choice = color(declaration('plan.css', '.plan-panel .plan-choice .plan-option', 'background'))
    plan_boundary = re.search(r'#[0-9a-fA-F]{3,6}\b', declaration('plan.css', '.plan-panel .plan-choice .plan-option', 'border'))[0]
    for label, surface in [('plan section', plan_surface), ('plan option', plan_choice)]:
        ratio(label + ' primary', primary, surface)
        ratio(label + ' secondary', secondary, surface)
        ratio(label + ' link', color(tokens['--hamcare-accent-cyan']), surface)
    ratio('plan option boundary inside', color(plan_boundary), plan_choice, 3)
    ratio('plan option boundary outside', color(plan_boundary), plan_surface, 3)
    ratio('plan radio focus', color(tokens['--hamcare-accent-cyan']), plan_choice, 3)
    ratio('disabled checkout text', color(declaration('plan.css', '.plan-actions .button:disabled', 'color')), color(declaration('plan.css', '.plan-actions .button:disabled', 'background')))
    consent_surface = color(declaration('checkout.css', '.account-card .checkout-consent', 'background'))
    consent_border = re.search(r'#[0-9a-fA-F]{3,6}\b', declaration('checkout.css', '.account-card .checkout-consent', 'border'))[0]
    ratio('Checkout consent text', color(declaration('checkout.css', '.account-card .checkout-consent', 'color')), consent_surface)
    ratio('Checkout consent boundary inside', color(consent_border), consent_surface, 3)
    ratio('Checkout consent boundary outside', color(consent_border), strong_worst, 3)
    ratio('Checkout disabled text', color(declaration('checkout.css', '#checkout-panel .button:disabled', 'color')), color(declaration('checkout.css', '#checkout-panel .button:disabled', 'background')))
    ratio('Stripe surrounding payment note', color(declaration('checkout.css', '#checkout-payment', 'color')), color(declaration('checkout.css', '#checkout-payment', 'background')))

    passed = sum(ok for _, ok in checks)
    print(f'Web brand checks: {passed}/{len(checks)} PASS')
    print(f'Contrast cases: {len(ratios)}; minimum text {min(value for _, value, minimum in ratios if minimum == 4.5):.2f}:1; minimum boundary/focus {min(value for _, value, minimum in ratios if minimum == 3):.2f}:1.')
    print('Contrast includes actual CSS colors, white-source glass/overlay worst cases; browser layout and actual assistive technology still require separate checks.')
    for name, ok in checks:
        if not ok:
            print('FAIL:', name)
    for name, value, minimum in ratios:
        if value < minimum:
            print(f'FAIL ratio: {name}: {value:.2f}:1 < {minimum}:1')
    return 0 if passed == len(checks) else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (KeyError, ValueError, OSError, subprocess.SubprocessError) as error:
        print('FAIL: unable to verify brand assets/styles:', error)
        raise SystemExit(1)
