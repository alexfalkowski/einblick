"""Build the self-contained synthetic UX preview from its template and pinned assets."""

from pathlib import Path


def render_preview():
    root = Path(__file__).resolve().parent
    template = (root / 'template.html').read_text()
    vendor = root / 'vendor'
    replacements = {
        '/* __UPLOT_CSS__ */': (vendor / 'uPlot.min.css').read_text(),
        '/* __UPLOT_JS__ */': (vendor / 'uPlot.iife.min.js').read_text(),
        '<!-- __UPLOT_LICENSE__ -->': (
            '<!-- uPlot ' + (vendor / 'UPLOT-VERSION.txt').read_text().strip()
            + '\n' + (vendor / 'UPLOT-LICENSE.txt').read_text() + '-->'
        ),
    }
    for marker, content in replacements.items():
        if template.count(marker) != 1:
            raise ValueError(f'Expected exactly one template marker: {marker}')
        template = template.replace(marker, content)
    return template


if __name__ == '__main__':
    root = Path(__file__).resolve().parent
    preview = render_preview()
    (root / 'index.html').write_text(preview)
    (root / 'validation').mkdir(exist_ok=True)
    app = preview.rsplit('<script>', 1)[1].split('</script>', 1)[0]
    (root / 'validation' / 'app.js').write_text(app)
    print('Built prototype/index.html and prototype/validation/app.js')
