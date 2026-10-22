# Editing the workshop website

The website is built by GitHub Pages using Jekyll. No JavaScript framework or
separate build workflow is needed.

## Everyday edits

- **Nextflow lesson:** edit `index.md`, or use **Edit this guide** on the website.
- **nf-core lesson:** edit `nf-core.md`. The lesson is at `/nf-core/` and includes the four-page workshop flyer.
- **Code examples:** edit the original `.sh`, `.nf`, or `.config` file. The guide
  includes these files directly, so the displayed code updates with them.
  This includes `nextflow.config` for RCAC task-shell setup and `hpc.config` for Slurm.
- **Appearance:** edit `assets/site.css`.
- **Copy buttons and navigation:** edit `assets/site.js`.
- **Header, page title, and footer:** edit `_layouts/guide.html`.

Keep the `{% include_relative ... %}` lines in `index.md`: they display the
actual workshop scripts. New `##` headings automatically appear in the sidebar.

Commit and push to `main`; GitHub Pages rebuilds the site. The publish source
is **main / (root)** in the repository's **Settings → Pages**. The workshop site
is at https://zhan4429.github.io/PurdueNfWorkshop/.

The [printable field guide](https://zhan4429.github.io/PurdueNfWorkshop/field-guide.html)
renders `index.md` and its script includes directly. There is no separate lesson
copy or committed PDF to keep updated. Edit `index.md` or a source script once;
both views update on the next Pages build. Students can use **Print / Save as PDF**
for an offline copy. Page count depends on the current lesson and print settings.

`field-guide.html` provides the print view; print styles are in `assets/site.css`.
