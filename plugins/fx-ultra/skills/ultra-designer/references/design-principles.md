# Design Principles — The Exhaustive Checklist

This is the deep rubric behind `ultra-designer`. `SKILL.md` is authoritative for the
**method** and the **verdict**; this file is the authoritative source for the **criteria**.
Every item here is checked against the **live DOM/CSSOM** via Playwright MCP
`browser_evaluate` / `browser_snapshot` — **NEVER** from a screenshot. A screenshot is
not evidence; a computed value is.

> How to read this file: each principle lists ⛔ failure conditions and ✅ pass conditions,
> followed by the **exact DOM/CSSOM signal** that proves which one you observed. If you can't
> name the computed value or a11y-tree fact you measured, you have NOT checked it.

---

## 1. Visual Hierarchy

The eye must land on the most important thing first, then travel in priority order. Hierarchy
is built from size, weight, color/contrast, spacing, and position — not decoration.

⛔ FAIL:
- Two elements compete for "most important" (same size + weight + color) when only one is the primary action.
- Body text and headings share the same computed `font-size`.
- The primary CTA is not visually dominant over secondary/tertiary actions.
- Visual weight contradicts semantic importance (a destructive action louder than the primary one).

✅ PASS:
- A measurable, monotonic step-down in emphasis from primary → secondary → tertiary.
- Headings are larger and/or heavier than body; the type scale has distinct, intentional steps.

How to check (DOM/CSSOM):
```js
// Compare emphasis of candidate "important" elements.
// font-size (px), font-weight, color luminance, and box area all feed "visual weight".
[...document.querySelectorAll('h1,h2,h3,.cta,[data-primary],button')].map(el => {
  const s = getComputedStyle(el);
  const r = el.getBoundingClientRect();
  return { tag: el.tagName, cls: el.className, fontSize: s.fontSize,
           fontWeight: s.fontWeight, color: s.color, area: Math.round(r.width*r.height) };
});
```
Assert the primary action outranks the rest on the combined size/weight/area signal.

---

## 2. Alignment & Spacing Scale

Everything aligns to a shared grid, and every gap is a value on the spacing scale (commonly a
4px or 8px base: 4, 8, 12, 16, 24, 32, 48, 64…). "Magic numbers" off the scale (13px, 7px, 21px)
are a tell that spacing was eyeballed.

⛔ FAIL:
- Gaps / paddings / margins that are not multiples of the base unit (e.g. `padding: 13px 7px`).
- Sibling elements whose left/top edges should align but differ by 1–6px (eyeballed alignment).
- Inconsistent gutters between cards/list items in the same collection.
- Optical misalignment between an icon and its label baseline.

✅ PASS:
- Every measured gap maps to a scale value (or a design token that resolves to one).
- Shared edges of grouped elements have identical computed offsets (`getBoundingClientRect`).

How to check (DOM/CSSOM):
```js
// Snap every gap to the 4px scale; flag off-scale values.
const scale = [0,4,8,12,16,20,24,32,40,48,56,64];
const onScale = v => scale.includes(Math.round(parseFloat(v)));
[...document.querySelectorAll('[class],[data-component]')].flatMap(el => {
  const s = getComputedStyle(el);
  return ['paddingTop','paddingRight','paddingBottom','paddingLeft','gap','rowGap','columnGap',
          'marginTop','marginBottom'].map(p => ({ el: el.className, prop: p, val: s[p],
          ok: !parseFloat(s[p]) || onScale(s[p]) }));
}).filter(x => !x.ok);   // <-- must be empty (or every entry justified by a token)
```
```js
// Alignment: edges that should line up must share an x (or y) within 0.5px.
const els = [...document.querySelectorAll('[data-col]')];
els.map(e => Math.round(e.getBoundingClientRect().left * 2) / 2);  // collect, assert all equal
```

---

## 3. Typography — Scale, Rhythm, Measure

Type is a system, not a pile of font sizes. Verify a modular scale, sane line-height, a readable
measure (line length), restrained weights, and consistent families.

⛔ FAIL:
- More than ~2 font families in play without intent.
- `line-height` near `1.0` on multi-line body copy (cramped) or > `1.8` (loose, broken rhythm).
- Body `font-size` < 14px on desktop or < 16px where it should be tappable/readable.
- Measure (characters per line) far outside ~45–90ch for long-form body text.
- Random one-off weights (e.g. 537) or a weight the loaded font doesn't actually ship (faux-bold synthesis).
- Letter-spacing applied to body text that harms readability, or absent on all-caps labels that need it.

✅ PASS:
- A discernible modular type scale (each step a consistent ratio of the last).
- Body `line-height` ≈ 1.4–1.6; headings tighter (≈ 1.1–1.3).
- Measure constrained via `max-width`/`ch` for prose.
- Weights drawn from a small, intentional set the font actually provides.

How to check (DOM/CSSOM):
```js
// Type system audit.
[...document.querySelectorAll('h1,h2,h3,h4,p,li,span,button,label')].map(el => {
  const s = getComputedStyle(el);
  return { tag: el.tagName, fontFamily: s.fontFamily, fontSize: s.fontSize,
           lineHeight: s.lineHeight, fontWeight: s.fontWeight, letterSpacing: s.letterSpacing };
});
```
```js
// Measure check for prose blocks: approximate chars-per-line from width / avg glyph width.
const p = document.querySelector('article p, .prose p, main p');
if (p) { const w = p.getBoundingClientRect().width;
  const ch = parseFloat(getComputedStyle(p).fontSize) * 0.5; // rough advance width
  Math.round(w / ch); }  // assert ~45–90
```
Detect faux-bold/italic synthesis by comparing requested weight to the font's available weights
(`document.fonts` set) — a synthesized weight is a polish failure.

---

## 4. Color System & Contrast (WCAG)

Color comes from a token palette, used consistently, and **every** text/UI element meets WCAG
contrast. AA is the floor: **4.5:1** for normal text, **3:1** for large text (≥ 24px, or ≥ 18.66px
bold) and for meaningful UI/graphical boundaries. AAA (**7:1** / **4.5:1**) is the bar for prose-heavy
or accessibility-forward products.

⛔ FAIL:
- Any text/background pair below its AA threshold.
- Disabled/placeholder text so low-contrast it's unreadable (still must be perceivable; aim ≥ 3:1 where it conveys info).
- Focus indicators, borders, icons, or chart strokes below 3:1 against their adjacent color.
- Color used as the *only* signal for state (error/success) with no text/icon/shape backup.
- Colors hard-coded off-palette instead of via design tokens / CSS custom properties.

✅ PASS:
- Computed contrast ratios meet or exceed the applicable threshold for every checked pair.
- State is conveyed redundantly (color + icon/text), not color alone.
- Colors resolve from CSS custom properties / token variables.

How to check (DOM/CSSOM) — compute the WCAG ratio from live computed colors:
```js
// WCAG contrast ratio from two computed colors. Returns a number; compare to threshold.
function lum(c){const [r,g,b]=c.match(/[\d.]+/g).slice(0,3).map(Number)
  .map(v=>{v/=255;return v<=0.03928?v/12.92:((v+0.055)/1.055)**2.4;});
  return 0.2126*r+0.7152*g+0.0722*b;}
function ratio(fg,bg){const a=lum(fg)+0.05,b=lum(bg)+0.05;return a>b?a/b:b/a;}
// Resolve effective background by walking up until a non-transparent bg is found.
function bgOf(el){let e=el;while(e){const c=getComputedStyle(e).backgroundColor;
  if(c && !/rgba?\(0, 0, 0, 0\)|transparent/.test(c))return c;e=e.parentElement;}return 'rgb(255,255,255)';}
[...document.querySelectorAll('p,span,a,button,label,h1,h2,h3,li,input,small')]
  .filter(el => el.textContent.trim())
  .map(el => { const s=getComputedStyle(el);
    return { text: el.textContent.trim().slice(0,24), fontSize: s.fontSize,
             ratio: +ratio(s.color, bgOf(el)).toFixed(2) }; })
  .filter(x => x.ratio < 4.5);   // <-- inspect each; large text may legitimately pass at 3:1
```
Treat `:focus-visible` outlines, borders, and icon strokes the same way against their neighbour.

---

## 5. Consistency & Token / Component Reuse

The same concept must look and behave the same everywhere. Reinvented one-off buttons,
copy-pasted spacing, and divergent shadows are polish debt.

⛔ FAIL:
- Two "primary buttons" with different padding, radius, or color.
- Shadows/radii/border colors that don't come from a shared token set.
- A component re-implemented inline instead of reusing the design-system component.

✅ PASS:
- Repeated UI affordances share computed `border-radius`, `box-shadow`, padding, and color.
- Values trace back to CSS custom properties / tokens.

How to check (DOM/CSSOM):
```js
// All buttons should cluster into a tiny set of (radius, shadow, padding, font) signatures.
const sig = el => { const s=getComputedStyle(el);
  return [s.borderRadius,s.boxShadow,s.paddingTop,s.paddingLeft,s.fontSize,s.fontWeight].join('|'); };
const groups = {}; document.querySelectorAll('button,.btn,[role=button]')
  .forEach(b => (groups[sig(b)] ??= []).push(b.className));
groups;   // <-- a handful of distinct signatures = good; dozens = inconsistency
```
```js
// Confirm tokens exist and are used (CSS custom properties on :root).
getComputedStyle(document.documentElement).cssText
  .match(/--[\w-]+:[^;]+/g);   // expect a token palette; spot-check usage in components
```

---

## 6. Gestalt — Proximity, Grouping, Similarity

Related things are close; unrelated things are apart. Proximity does more grouping work than
borders or boxes ever should.

⛔ FAIL:
- A label visually closer to the *next* field than to its own input (ambiguous grouping).
- Uniform spacing everywhere, so no group structure is perceivable.
- Section separation relies only on borders when whitespace should carry it.

✅ PASS:
- Intra-group gaps are measurably smaller than inter-group gaps (proximity creates groups).
- Similar items share visual treatment; dissimilar items are differentiated.

How to check (DOM/CSSOM): measure label↔input vs field↔field gaps with `getBoundingClientRect`
and assert intra-group < inter-group.

---

## 7. Density & Whitespace

Whitespace is an active design material, not wasted space. Verify breathing room around content,
comfortable touch/click targets, and no claustrophobic clusters — without sprawling, content-starved
layouts either.

⛔ FAIL:
- Interactive targets crammed with < 8px between them (mis-tap risk).
- Content edge-to-edge against its container with no padding.
- Cards/sections with wildly inconsistent internal padding.

✅ PASS:
- Consistent, scale-based internal padding and inter-element rhythm.
- Adequate separation between independent interactive targets.

---

## 8. Affordance & Feedback

Interactive things must look interactive, and every action must produce immediate, perceptible
feedback. (The exhaustive per-state matrix lives in `SKILL.md`; this is the principle.)

⛔ FAIL:
- A clickable element with no hover/focus/active affordance — indistinguishable from static text.
- An action (submit, save, delete) that gives no visual acknowledgement (no loading/disabled/success signal).
- Cursor not `pointer` on a custom clickable; `cursor: default` on something that acts like a button.

✅ PASS:
- Every interactive element changes a computed property on hover/focus/active.
- Async actions surface loading and result states.

How to check (DOM/CSSOM): drive the state (see SKILL.md state matrix) and diff computed styles
before/after; assert `cursor`, `background`, `outline`, or `transform` changed.

---

## 9. Motion & Transitions

Motion clarifies change and provides feedback; it must be tasteful, consistent, fast enough to feel
responsive, and **always** respect `prefers-reduced-motion`.

⛔ FAIL:
- State changes that should animate snap instantly (jarring), e.g. a drawer that teleports open.
- Gratuitous/slow animation that delays the user (> ~400ms for a simple UI transition).
- Inconsistent easing/durations across similar transitions.
- Motion that ignores `prefers-reduced-motion: reduce` (vestibular-disorder hazard + a11y failure).

✅ PASS:
- Transitions on the right properties (transform/opacity, not layout-thrashing top/left).
- Durations roughly 120–300ms for micro-interactions; consistent easing curves (tokens).
- Under reduced-motion, non-essential animation is removed or made instantaneous.

How to check (DOM/CSSOM):
```js
// Read declared transitions/animations and verify reduced-motion handling.
const s = getComputedStyle(document.querySelector('.drawer,.modal,[data-animated]') || document.body);
({ transitionProperty: s.transitionProperty, transitionDuration: s.transitionDuration,
   transitionTimingFunction: s.transitionTimingFunction, animationName: s.animationName });
```
```js
// Does the app actually honor reduced-motion? Read the media query state the page sees.
matchMedia('(prefers-reduced-motion: reduce)').matches;
```
Drive reduced-motion via the Playwright context (see SKILL.md) and re-read durations: non-essential
transitions should collapse to ~0ms.

---

## 10. Responsiveness & Adaptivity

The layout must hold from small phone to wide desktop: no horizontal overflow, no broken/overlapping
elements, sensible reflow, and touch-friendly targets on small viewports.

⛔ FAIL:
- Horizontal scrollbar at any tested viewport (`scrollWidth > clientWidth`).
- Content clipped/overlapping or text overflowing its container.
- Touch targets smaller than ~44×44px on touch viewports.
- Fixed pixel widths that don't reflow; images without `max-width:100%`.

✅ PASS:
- No overflow at 360 / 768 / 1024 / 1440 (and any product-specific breakpoints).
- Layout reflows intentionally at breakpoints; targets stay tappable.

How to check (DOM/CSSOM):
```js
// Overflow detection at the current viewport.
({ overflowX: document.documentElement.scrollWidth > document.documentElement.clientWidth,
   widest: [...document.querySelectorAll('*')]
     .filter(el => el.getBoundingClientRect().right > window.innerWidth + 1)
     .slice(0,10).map(el => ({ cls: el.className, right: Math.round(el.getBoundingClientRect().right) })) });
```
```js
// Touch-target size audit (run at a mobile viewport).
[...document.querySelectorAll('a,button,[role=button],input,select')]
  .map(el => { const r = el.getBoundingClientRect();
    return { cls: el.className, w: Math.round(r.width), h: Math.round(r.height) }; })
  .filter(t => t.w < 44 || t.h < 44);
```

---

## 11. Content Robustness (Edge Content)

Polish is what happens to the layout when the data is ugly. Verify long strings, empty collections,
huge numbers, missing images, and error payloads don't break it.

⛔ FAIL:
- Long unbroken text overflows or pushes layout (no `overflow-wrap`/`text-overflow`/`min-width:0`).
- Empty state renders a blank void instead of a designed empty state.
- Missing image leaves a broken-image icon / collapses layout (no `alt`, no fallback, no fixed box).
- Pluralization/number formatting breaks (e.g. "1 items").

✅ PASS:
- Truncation/wrapping handled deliberately; tooltips/expansion where truncation hides info.
- Designed empty, error, and loading states.

How to check (DOM/CSSOM): inject long text / empty data via `browser_evaluate` and re-measure
overflow (see §10). Verify `text-overflow`, `overflow-wrap`, `min-width:0` on flex children.

---

## 12. Accessibility (Polish-Grade)

A11y failures ARE polish failures. The accessibility tree (`browser_snapshot`) is your source of truth.

⛔ FAIL:
- Interactive elements with no accessible name (empty `aria-label` + no text + icon-only).
- `:focus-visible` removed (`outline: none`) with no replacement indicator — keyboard users are lost.
- Wrong/absent semantic roles (a `div` acting as a button without `role`/keyboard handling).
- Form inputs without associated `<label>`/`aria-labelledby`.
- Focus order that doesn't match visual/reading order; focus traps in non-modal UI; no focus return after modal close.
- Heading levels skipped (h1 → h4) breaking document outline.

✅ PASS:
- Every interactive node has an accessible name + correct role in the a11y tree.
- A visible focus indicator (outline/ring/shadow with ≥ 3:1 contrast) on every focusable element.
- Logical focus order; modals trap + restore focus; landmarks/headings well-structured.

How to check (a11y tree + DOM):
```js
// Focusables missing an accessible name (rough heuristic; confirm against browser_snapshot).
[...document.querySelectorAll('a,button,input,select,textarea,[role=button],[tabindex]')]
  .filter(el => !(el.getAttribute('aria-label') || el.getAttribute('aria-labelledby')
    || el.textContent.trim() || el.labels?.length || el.getAttribute('title')))
  .map(el => el.outerHTML.slice(0, 80));   // <-- must be empty
```
```js
// Focus-visible must produce a perceptible indicator. Focus, then read the outline/box-shadow.
const el = document.querySelector('button, a');
el.focus();
const s = getComputedStyle(el);
({ outlineStyle: s.outlineStyle, outlineWidth: s.outlineWidth, boxShadow: s.boxShadow });
```
Always reconcile with `mcp__playwright__browser_snapshot` — the accessibility tree shows the
*computed* role/name pairs the assistive-tech user actually receives.

---

## Threshold Quick Reference

| Criterion | AA / minimum | AAA / target |
|-----------|--------------|--------------|
| Text contrast (normal < 24px / < 18.66px bold) | 4.5:1 | 7:1 |
| Large text (≥ 24px, or ≥ 18.66px bold) | 3:1 | 4.5:1 |
| UI components / graphical objects / focus ring | 3:1 | — |
| Body line-height | 1.4–1.6 | tuned per family |
| Prose measure | 45–90ch | 60–75ch |
| Touch target | 44×44px (24×24 min CSS, AA) | comfortable ≥ 48px |
| Micro-interaction duration | 120–300ms | consistent easing tokens |
| Spacing base unit | multiples of 4px | multiples of 8px |

All values above are read from the **live** computed styles / a11y tree — never inferred from a
rendered image.
