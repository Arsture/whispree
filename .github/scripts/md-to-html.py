#!/usr/bin/env python3
"""Convert markdown changelog to HTML for Sparkle release notes."""
import html as h
import sys
import os


def md_to_html(md_text):
    lines = md_text.strip().split('\n')
    parts = []
    in_ul = False

    for line in lines:
        s = line.strip()
        if not s:
            if in_ul:
                parts.append('</ul>')
                in_ul = False
            continue
        if s.startswith('### '):
            if in_ul:
                parts.append('</ul>')
                in_ul = False
            parts.append(f'<h3>{h.escape(s[4:])}</h3>')
        elif s.startswith('## '):
            if in_ul:
                parts.append('</ul>')
                in_ul = False
            parts.append(f'<h2>{h.escape(s[3:])}</h2>')
        elif s.startswith('- '):
            if not in_ul:
                parts.append('<ul>')
                in_ul = True
            parts.append(f'<li>{h.escape(s[2:])}</li>')
        else:
            if in_ul:
                parts.append('</ul>')
                in_ul = False
            parts.append(f'<p>{h.escape(s)}</p>')

    if in_ul:
        parts.append('</ul>')

    return '\n'.join(parts)


TEMPLATE = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<style>
body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 13px; line-height: 1.6; color: #1d1d1f; padding: 16px; background: transparent; }
@media (prefers-color-scheme: dark) { body { color: #f5f5f7; } }
h2 { font-size: 16px; margin: 16px 0 8px; }
h3 { font-size: 14px; margin: 12px 0 6px; }
ul { padding-left: 20px; margin: 4px 0 12px; }
li { margin: 2px 0; }
p { margin: 6px 0; }
</style>
</head>
<body>
CONTENT_PLACEHOLDER
</body>
</html>"""


if __name__ == '__main__':
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    with open(input_file, 'r') as f:
        md = f.read()

    content = md_to_html(md)
    html_doc = TEMPLATE.replace('CONTENT_PLACEHOLDER', content)

    os.makedirs(os.path.dirname(output_file) or '.', exist_ok=True)
    with open(output_file, 'w') as f:
        f.write(html_doc)
