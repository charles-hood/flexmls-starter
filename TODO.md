# FlexMLS Starter — TODO

## High value, low effort

- [ ] **Update `property-redirect.html`** — still has old basic styling, should match the redesigned template
- [ ] **SVG logo option in `generate.sh`** — offer to generate a simple text-based SVG logo from the company name, since most small brokerages don't have a logo file handy
- [ ] **Security fix in `generate.sh`** — the `prompt()` function uses `eval` for variable assignment, which is a shell injection risk. Should use `declare` or `read` directly

## Medium value, medium effort

- [ ] **Accessibility pass** — modals don't trap focus, missing `aria-modal`, no skip-nav link, close buttons need better screen reader labels. Important for ADA compliance, which real estate sites occasionally get dinged for
- [ ] **Structured data (JSON-LD)** — template `LocalBusiness` and `RealEstateAgent` schema into `index.html`. Zero runtime cost, helps SEO, just more `{{PLACEHOLDERS}}`
- [ ] **Fix CSV parser** — the bash `IFS` splitting breaks on commas inside quoted fields. The Python replacement engine is already there; CSV parsing should use it too

## Nice to have

- [ ] **Favicon from logo** — `generate.sh` could auto-generate a favicon from the provided logo image using `sips` (macOS) or ImageMagick, instead of using the generic default
- [ ] **Smoke test script** — a simple script that runs the generator with test data and validates the output has no remaining `{{PLACEHOLDER}}` tokens
