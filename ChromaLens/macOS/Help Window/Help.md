# ChromaLens Help

ChromaLens shows part of your screen the way it may look to someone with a color vision deficiency. Move the lens over any app (a simulator, a browser, a design tool) and compare it with the original colors. The app you're looking at doesn't need to know about ChromaLens.

---

## About Color Vision Deficiency

### How we see color

The retina has three kinds of **cone** cells. Each responds most strongly to a different part of the visible spectrum:

- **L cones** (long wavelengths, often called "red" cones)
- **M cones** (medium wavelengths, "green" cones)
- **S cones** (short wavelengths, "blue" cones)

The brain compares the signals from the three cone types to tell colors apart. **Rod** cells handle low-light vision and play no real part in color vision.

A **color vision deficiency** (CVD), often called color blindness, happens when one or more cone types are missing, don't work, or respond to a shifted part of the spectrum. Very few people see no color at all. Most see color but confuse certain colors that look clearly different to others.

### How common it is

- Red-green deficiencies are by far the most common. Commonly cited figures are about **1 in 12 men (8%)** and **1 in 200 women (0.5%)** among people of Northern European ancestry. Rates vary between populations.
- The genes for the L and M cones sit on the X chromosome. Men have one X chromosome, so a single altered copy is enough, which is why far more men are affected.
- Blue-yellow (tritan) deficiencies and complete color blindness are rare and affect men and women about equally.
- CVD can also be **acquired** later in life, from eye diseases such as glaucoma, macular degeneration or cataracts, from some medications, or with age. Acquired deficiencies often affect blue-yellow discrimination.

### Kinds of deficiency

Deficiencies are grouped by which cone type is affected and how strongly:

- **Anomalous trichromacy** (names ending in *-anomaly*): all three cone types are present, but one responds to a shifted part of the spectrum. Severity ranges from barely noticeable to almost dichromatic.
- **Dichromacy** (names ending in *-anopia*): one cone type is missing or doesn't work, so color is built from only two signals.
- **Monochromacy** (achromatopsia): little or no functioning cone vision, so there's little or no perception of hue.

---

## The Simulations

| Simulation | Affected cones | What it means | ChromaLens model |
|---|---|---|---|
| Deuteranomaly | M ("green") | Reduced green sensitivity; reds, greens, browns and oranges can look alike | Machado model, adjustable severity |
| Deuteranopia | M ("green") | No working green cones; strong red-green confusion | Machado model, full severity |
| Protanomaly | L ("red") | Reduced red sensitivity; reds look darker and closer to greens | Machado model, adjustable severity |
| Protanopia | L ("red") | No working red cones; reds can look very dark, almost black | Machado model, full severity |
| Tritanomaly | S ("blue") | Reduced blue sensitivity; blue and green, yellow and pink can look alike | Machado model, adjustable severity |
| Tritanopia | S ("blue") | No working blue cones; blues and greens, yellows and violets are confused | Machado model, full severity |
| Achromatomaly | Several | Reduced overall color discrimination; colors look washed out | Approximation: partial desaturation |
| Achromatopsia | All cones | Little or no perception of hue | Approximation: grayscale |

### Deuteranomaly

The most common color vision deficiency, often cited as affecting about 5% of men. The M cones respond to light closer to the L cones than usual, so reds, oranges, yellows and greens are harder to tell apart. Mild cases may go unnoticed for years.

### Deuteranopia

The M cones are missing or don't work. Commonly cited at about 1% of men. Red and green, and colors that differ mainly in their red-green balance, can look the same, mostly as shades of yellow, brown and blue.

### Protanomaly

The L cones respond closer to the M cones than usual. Commonly cited at about 1% of men. Besides red-green confusion, reds look less bright.

### Protanopia

The L cones are missing or don't work. Commonly cited at about 1% of men. Reds can look very dark or black, which matters for things like red warning text on a dark background.

### Tritanomaly

The S cones work less well. Rare. Blue and green, and yellow and pink, become harder to tell apart.

### Tritanopia

The S cones are missing or don't work. Rare, with estimates around 1 in 10,000 people or fewer. Blues and greens, and yellows and violets or light grays, can be confused.

### Achromatomaly

Incomplete achromatopsia. Very rare. Some color perception remains, but colors look strongly desaturated. ChromaLens approximates this by blending toward grayscale; use the **Desaturation Amount** slider to choose how far.

### Achromatopsia

Complete achromatopsia, or rod monochromacy. Estimated at about 1 in 30,000 people. With little or no working cone vision, the world appears in shades of gray. People with achromatopsia usually also have strong light sensitivity, reduced sharpness of vision and involuntary eye movements. **A color filter can't show those effects**: ChromaLens shows only the loss of hue.

---

## Designing for Color Vision Deficiency

- **Don't use color as the only way to convey information.** Add text labels, icons, patterns or position. This is WCAG 2.2 success criterion 1.4.1, *Use of Color*.
- **Keep enough contrast.** WCAG asks for at least 4.5:1 for body text and 3:1 for large text, icons and essential graphics. Lightness contrast survives every kind of CVD; hue differences often don't.
- **Be careful with red/green pairs** for status, charts and maps. Red and green that differ only in hue are the classic failure.
- **Label charts directly** instead of relying on a color legend, and vary marker shape or line style.
- **Test with several simulations**, and with real people where it matters. Simulations show color *differences*; they don't capture how a person experiences their own vision.

---

## Using ChromaLens

### The lens

- **Show or hide** the lens from the menu bar icon or with **⌃⌥⌘L**.
- **Move** the lens by dragging the toolbar (anywhere that isn't a button).
- **Resize** it by dragging the colored border, on any side or corner.
- Inside the lens, clicks and scrolling go straight through to the app beneath it.
- The toolbar moves below the lens if there isn't room for it above.
- **Hide the controls** (toolbar and border) with the dashed-rectangle button or **⌃⌥⌘H**. A thin outline stays visible. Bring the controls back with the same shortcut or from the menu bar.

### Simulation controls

- **Simulation**: choose the deficiency to simulate, or Original Colors.
- **Simulation Severity** (the *-anomaly* simulations): how strongly the affected cones are shifted, from 10% to 90% in the Machado model. Each family remembers its own value. The *-anopia* simulations always use full severity.
- **Desaturation Amount** (achromatomaly): how far colors are blended toward grayscale. This is a visual approximation, not a physiological severity.
- **Blend with Original**: mixes the simulated and original images, from 0% (fully simulated) to 100% (original). This is a viewing aid, not a measure of severity.
- **Original**: the toolbar toggle shows the original colors until you turn it off. Hold **⌃⌥⌘O** to see the original colors only while the keys are held.

### Keyboard shortcuts

| Action | Default |
|---|---|
| Show/hide lens | ⌃⌥⌘L |
| Hold to show original colors | ⌃⌥⌘O |
| Next simulation | ⌃⌥⌘] |
| Previous simulation | ⌃⌥⌘[ |
| Show/hide lens controls | ⌃⌥⌘H |

Change them in **Settings › Shortcuts**. A warning appears next to a shortcut that's already taken by another app.

### Displays and Spaces

The lens stays at the same place on every Space, including over full-screen apps. It belongs to one display at a time. If you drag it onto another display, part of it shows a gray hatch until you let go; then it moves fully onto the display that holds most of it, and capture switches there. If its display is disconnected, the lens moves to the main display.

---

## About the Simulation Model

The protan, deutan and tritan simulations use the physiologically based model by **Machado, Oliveira and Fernandes (2009)**, *A Physiologically-based Model for Simulation of Color Vision Deficiency* (IEEE Transactions on Visualization and Computer Graphics). ChromaLens uses the authors' published matrices for severities 0.0 to 1.0 in steps of 0.1, and interpolates linearly between neighboring steps.

Color pipeline:

1. The screen region under the lens is captured as 8-bit sRGB.
2. Each pixel is converted to linear light.
3. The simulation matrix for the chosen deficiency and severity is applied.
4. The result is clamped to the valid range and converted back to sRGB.
5. The blend with the original is applied.

The achromatic modes use Rec. 709 luminance (0.2126 R + 0.7152 G + 0.0722 B in linear light). Achromatopsia is full grayscale; achromatomaly blends toward it by the desaturation amount.

ChromaLens is **a simulation tool, not a diagnostic test**. It can't tell you whether you or anyone else has a color vision deficiency, and it doesn't certify that a design meets accessibility guidelines.

---

## Privacy

- ChromaLens needs Screen Recording permission to see what's under the lens. It captures only the area around the lens, and excludes its own windows.
- Frames are processed in memory on your Mac. Nothing is saved to disk or sent anywhere.
- While capture runs, macOS shows its screen recording indicator. **Stop Capture** in the menu bar hides the lens and stops capture immediately. **Settings › General** controls how long capture keeps running after you hide the lens.

---

## Known Limitations

- **Standard color range only.** Wide-gamut (Display P3) colors are converted to sRGB before simulation, so very saturated colors may look slightly duller in the lens, even in Original Colors. HDR content isn't simulated accurately.
- **One display at a time.** The lens can't span displays.
- **Protected content.** Video and other content that macOS protects from capture may appear blank or be missing in the lens. ChromaLens doesn't try to get around this.
- **Small delay.** The lens shows a captured copy of the screen, so it trails live content by a frame or two, most noticeably while scrolling or dragging the lens.
- **Non-color symptoms.** Light sensitivity, reduced sharpness and other effects that come with some conditions, especially achromatopsia, can't be shown by a color filter.
