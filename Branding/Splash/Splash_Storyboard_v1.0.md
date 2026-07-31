# Media QC Inspector

## Splash Screen Storyboard v1.0

**Version:** 1.0

**Status:** Planned (v0.6.x)

---

# Objective

The splash screen should communicate confidence, precision, and professionalism while reinforcing the Media QC Inspector brand.

The animation should feel purposeful—not decorative—and should never delay the user's workflow unnecessarily.

Target duration:

**1.8–2.2 seconds**

Display only when application startup requires noticeable initialization (cold launch or long startup).

---

# Animation Sequence

## Scene 1 — Initialize

**Duration:** 0.0–0.4 seconds

Background fades to the official Media QC Inspector deep navy.

No text.

No icon.

A soft blue light begins sweeping across the screen.

Purpose:

The application is beginning its inspection.

---

## Scene 2 — Media Frame

**Duration:** 0.4–0.8 seconds

As the light passes…

The media frame fades into view.

Only the frame appears.

The rest of the icon remains invisible.

Purpose:

Represents the media being prepared for inspection.

---

## Scene 3 — Inspection

**Duration:** 0.8–1.1 seconds

The magnifying glass fades in.

Animation:

- Fade opacity
- Scale from 95% → 100%
- Ease Out

No bounce.

No overshoot.

Purpose:

Inspection begins.

---

## Scene 4 — Validation

**Duration:** 1.1–1.3 seconds

The checkmark softly fades into the magnifying glass lens.

No movement.

Simply appears.

Purpose:

Inspection completed successfully.

---

## Scene 5 — Application Identity

**Duration:** 1.3–1.6 seconds

Application title fades in.

**Media QC Inspector**

Centered.

Large.

White.

SF Pro Display Bold.

---

## Scene 6 — Brand Tagline

**Duration:** 1.6–1.9 seconds

The tagline appears one word at a time.

- Validate.
- Inspect.
- Deliver.

Each word fades independently.

Approximately 120–150 ms apart.

Colors:

- Validate. → Blue
- Inspect. → Cyan
- Deliver. → Green

Purpose:

Reinforce the application's workflow.

---

## Scene 7 — Transition

**Duration:** 2.0 seconds

Brief pause (~200 ms).

Splash fades naturally into the main application window.

No abrupt cut.

No sound.

---

# Motion Philosophy

Animations should communicate:

- Initialization
- Inspection
- Validation
- Readiness

They should never exist simply for decoration.

Every animation has a purpose.

---

# Visual Style

Background:

Official Media QC Inspector Navy

Icon:

Official application icon

Typography:

SF Pro Display

Spacing:

Centered vertically and horizontally.

---

# Audio

None.

Professional applications should launch silently.

---

# Future Enhancement

A future version may allow the splash icon to smoothly transition into the About window icon position, creating a continuous visual experience.

---

# Animation Timeline

```
0.0
│
├── Blue sweep
│
0.4
│
├── Media frame fades in
│
0.8
│
├── Magnifying glass appears
│
1.1
│
├── Checkmark appears
│
1.3
│
├── Media QC Inspector
│
1.6
│
├── Validate.
│
1.7
│
├── Inspect.
│
1.8
│
├── Deliver.
│
2.0
│
└── Application opens
```

---

# Design Goals

Every launch should communicate:

- Professional
- Precise
- Trustworthy
- Calm
- Confident

The splash screen should leave the impression that the application has just completed a quality inspection and is now ready to begin work.