# Editing the workshop website

The website is built by GitHub Pages using Jekyll. No JavaScript framework or
separate build workflow is needed.

## Everyday edits

- **Lesson text:** edit `index.md`, or use **Edit this guide** on the website.
- **Code examples:** edit the original `.sh`, `.nf`, or `.config` file. The guide
  includes these files directly, so the displayed code updates with them.
- **Appearance:** edit `assets/site.css`.
- **Copy buttons and navigation:** edit `assets/site.js`.
- **Header, hero, and footer:** edit `_layouts/guide.html`.

Keep the `{% include_relative ... %}` lines in `index.md`: they display the
actual workshop scripts. New `##` headings automatically appear in the sidebar.

Commit and push to `main`; GitHub Pages rebuilds the site. The publish source
is **main / (root)** in the repository's **Settings → Pages**. The workshop site
is at https://zhan4429.github.io/PurdueNfWorkshop/.

The HTML and PDF field guides remain available as printable companions.
Website text is edited in `index.md`; printable guides are separate artifacts.
