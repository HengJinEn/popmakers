# POP MAKERS

A responsive, buildless landing page with real interactive GLB connectors using Google's `<model-viewer>` 4.3.1.

## Run locally on Windows

Open PowerShell in this folder and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\serve.ps1
```

Visit **http://127.0.0.1:8080**. Keep the terminal open and press Ctrl+C to stop. For another port, append `-Port 8081`.

VS Code Live Server or any static HTTP server also works. Serve the folder over HTTP rather than opening `index.html` as a `file://` URL, because browser modules and GLB fetching need a server. Node, Python, a build step, and Next.js are not required. Google Fonts and the pinned model-viewer CDN need internet access; rounded fonts and included static model posters are the fallbacks.

## Files

- `index.html`: page sections, semantic markup, native FAQ accordions, a catapult energy showcase, and reusable SVG illustrations.
- `css/style.css`: brand variables, mobile-first behavior, sticker styling, and reduced-motion support.
- `js/script.js`: connector catalog, 3D loading/errors, rotation, mobile navigation, section reveals, and honest email preview.
- `assets/models/`: six active GLBs, including Prism, plus preserved original model assets. Current geometry/materials are used as supplied.
- `assets/images/`: supplied logo, real catapult build photo, and original favicon.
- `assets/posters/`: transparent PNGs rendered from the actual GLB triangles for offline/error previews.
- `scripts/generate-posters.ps1`: dependency-free poster generation, if models are replaced.
- `img/`: original user assets, preserved.

## Replace or confirm before launch

1. **Kit CTA:** all kit links open the supplied Google interest form in a new tab. Its URL is centralized in `KIT_FORM_URL` in `js/script.js`, with matching HTML fallback links. Confirm the form allows responses from your intended audience.
2. **Email form:** explicitly marked preview-only. It validates format but sends and saves nothing, and never claims successful signup. Connect your mailing-list service and replace the preview handler/copy when ready. Do not place service secrets in browser JavaScript.
3. **Testimonials:** all quotes and star ratings are clearly labeled illustrative samples. Replace with approved real quotes/ratings and attribution, or remove this section.
4. **Projects:** the four SVGs are illustrated inspiration, not tested build guides. The catapult card links to a real build photo and an energy learning activity; assembly instructions are not included.
5. **Kit information:** confirm final contents, quantities, ages, instructions, material compatibility, and safety wording. The brief supplies ages 6+; there are no invented certifications, prices, or checkout claims.
6. **Socials:** icons are non-clickable “coming soon” placeholders. Add your real profile URLs when available.
7. **Connector names/copy:** filenames drive the six labels. Descriptions and “Imagine” suggestions are creative draft copy; verify against your real kit.

## Inspected models and assumptions

The six active files are GLB v2, contain one mesh with one primitive, have no image textures or extension dependencies, and total 113,276 bytes. Mesh names vary between exports. The selector swaps complete GLB files, rather than relying on mesh names.

| Model | Position vertices | Bounds (export units) | Material |
| --- | ---: | --- | --- |
| 180 Connector | 350 | 21 × 7 × 7 | Cyan, slightly metallic |
| 90 Connector | 600 | 14 × 14 × 7 | Cyan, matte |
| 360 Connector | 575 | 21 × 7 × 21 | Cyan, slightly metallic |
| 180 Connector 3 Point | 452 | 21 × 7 × 14 | Cyan, slightly metallic |
| 180 Connector 8 Point | 1076 | 23 × 15 × 15 | Cyan, slightly metallic |
| Prism Connector | 929 | ≈14 × 7 × 14.34 | Cyan, slightly metallic |

Physical units are unconfirmed. Automatic camera fitting presents each piece clearly without treating these numbers as a product measurement or rescaling the source files. Supplied cyan materials are preserved. CAD file names do not imply a moving hinge or wheel mechanism.

The hero starts with the 360 Connector. The showcase loads near the viewport and swaps between all six models. Models stop auto-rotating offscreen or when the tab is hidden. Reduced motion disables automatic rotation and decorative animation; the explicit “Spin it!” button then makes a single quarter turn.

Regenerate fallback posters after replacing model files:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-posters.ps1
```

The poster renderer uses actual mesh vertices/indices with a fixed orthographic camera and approximate lighting; these are geometry previews, not product photography.

## Catapult energy showcase

`#catapult` follows Projects and uses `assets/images/catapult-build.png`, the supplied build photograph, without cropping the catapult. English explanations include Malay science terms. The SVG sequence illustrates elastic potential energy stored in the stretched band, its transformation into kinetic energy, and energy transferred to the surroundings as sound and heat.

The learning outcomes support KSSR Science Year 4 Unit 7 standards 7.1.3–7.1.6 (energy forms, transformation, conservation, and communicating observations), based on the [KPM DSKP, printed page 61](https://asiemodel.net/wp-content/uploads/2022/08/DSKP-KSSR-SEMAKAN-2017-SAINS-TAHUN-4-V2.pdf#page=73). The section covers these selected outcomes, rather than the entire Energy unit. Its experiment compares gentle pull-back distances using repeated trials and a consistent setup, with grown-up supervision and soft projectiles.

## Browser verification

Serve the site, then open `verification/checks.html` and `verification/no-js-checks.html` in Chrome. Run the former again with reduced motion enabled. Checks cover all six models, Prism selection, static fallback/retry, navigation, image loading, and responsive overflow.

For automated checks and screenshots, start a separate headless Chrome with remote debugging on port 9227 and an isolated profile, then run `powershell -NoProfile -ExecutionPolicy Bypass -File .\verification\run-browser-checks.ps1`. The runner uses PowerShell and Chrome's debugging protocol without third-party packages. It writes `verification/results.json` and catapult/kit screenshots at 375, 768, and 1440 pixels. Optional `-DebugPort` and `-SitePort` arguments override the defaults.
