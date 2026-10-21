# Color Vision Lens for macOS

**Product and technical specification**  
**Version:** 1.0 (draft)  
**Date:** 21 October 2026  
**Status:** Proposal / implementation-ready MVP plan

## 1. Executive summary

Color Vision Lens is a macOS utility that places a **movable, resizable, live color-vision-simulation window** above any application. The area shown inside the lens displays an approximation of how the underlying desktop content may appear to someone with a selected color vision deficiency (CVD). The surrounding desktop stays unmodified.

The app targets designers, accessibility specialists, iOS/Android developers using simulators, web developers, and QA testers. It requires **no integration with the application being inspected**.

The implementation captures desktop frames through **ScreenCaptureKit**, transforms pixels on the GPU with **Metal**, and presents the result inside a lightweight **AppKit overlay window**. The capture explicitly excludes the utility's own windows to prevent recursive feedback. The interior of the lens can be click-through, allowing interaction with applications beneath it.

Eight simulation presets are required: deuteranomaly, deuteranopia, protanomaly, protanopia, tritanomaly, tritanopia, achromatomaly, and achromatopsia. Normal/off is also offered. The six cone-related presets use a documented, severity-aware color simulation model. The two achromatic modes are labeled approximations rather than clinical reproductions of a person's full visual experience.

**Primary technical risks:** real-time latency, robust display-coordinate mapping, color-management accuracy, capture permission and privacy behavior, and multi-display/window occlusion semantics.

---

## 2. Goals and non-goals

### Goals

1. Display a freely movable and resizable color-vision simulation lens over arbitrary macOS apps.
2. Support all eight requested CVD presets and a normal/off view.
3. Maintain useful interactive responsiveness while the underlying app scrolls, animates, or receives pointer input.
4. Allow an instant original/simulated comparison without disrupting the underlying application.
5. Avoid app-specific integrations, device-simulator APIs, and application source-code dependencies.
6. Produce a repeatable, documented simulation with automated reference tests.
7. Remain privacy-conscious: capture frames in memory and do not upload or persist them by default.

### Non-goals for MVP

- Certifying WCAG conformance or diagnosing color vision conditions.
- Automatically identifying all inaccessible UI elements.
- Accurately reproducing non-color symptoms associated with achromatopsia (e.g., photophobia and reduced acuity).
- Filtering protected/DRM content that macOS does not expose to capture.
- Supporting arbitrary lens shapes, compositing over separate Spaces, or lens spanning multiple displays in the first release.
- Guaranteeing 60 fps or a specific latency on every supported Mac.

## 3. Target platform and constraints

- **Platform:** macOS desktop, Apple silicon prioritized.
- **Minimum OS:** choose based on tested ScreenCaptureKit capabilities; propose macOS 14+ for the MVP, to be confirmed in an API compatibility spike.
- **Languages:** Swift, Metal Shading Language.
- **Frameworks:** AppKit, SwiftUI for settings, ScreenCaptureKit, Metal/MetalKit, CoreGraphics, CoreVideo, AVFoundation/CoreMedia where needed.
- **Distribution:** initially developer-signed/notarized direct download. Evaluate Mac App Store sandbox/entitlement constraints separately.
- **Permissions:** macOS Screen Recording / Screen & System Audio Recording consent as required by the running OS. The app must explain the permission and handle denial and revocation.

**Core architectural constraint:** an ordinary third-party macOS window cannot simply apply an arbitrary Metal shader to pixels *already composited behind that window* through a public universal backdrop API. The visible lens therefore uses a capture-transform-present pipeline. This is an apparent overlay, not a zero-latency compositor-level filter.

## 4. User stories

- As an iOS developer, I can drag the lens above Simulator or Device Hub and inspect live screens without modifying my iOS app.
- As an Android developer, I can position the lens above an emulator.
- As a designer, I can resize the lens over parts of a browser or design editor to compare interface colors.
- As a QA tester, I can choose any of eight CVD presets and switch immediately to the original appearance.
- As a keyboard-first user, I can toggle the lens and change presets through shortcuts.
- As a privacy-conscious user, I can see when desktop capture is active and stop capture immediately.

## 5. Functional requirements

### 5.1 Lens window

| ID | Requirement | Priority |
|---|---|---|
| L-01 | Movable lens above standard application windows | Must |
| L-02 | Freely resizable rectangle with minimum size (proposed 240 × 160 pt) | Must |
| L-03 | Filter only the area visually covered by the lens | Must |
| L-04 | Lens content is click-through to underlying applications | Must |
| L-05 | Clearly exposed drag handle/title bar and resize affordance; these remain interactive | Must |
| L-06 | Toggle visible/hidden and simulated/original by keyboard shortcut | Must |
| L-07 | Restore prior position, size, and preset on relaunch | Should |
| L-08 | Constrain lens to one display in MVP; handle edge cases visibly | Must |
| L-09 | Optional border and always-on-top setting | Should |
| L-10 | Multi-lens support | Later |

### 5.2 Presets

The product must expose **normal/off plus eight modes**:

| Preset identifier | User-facing name | Meaning | Model plan |
|---|---|---|---|
| `deuteranomaly` | Deuteranomaly | Reduced green-cone discrimination | Machado-type deutan continuum; default intermediate severity |
| `deuteranopia` | Deuteranopia | Modeled green-cone dichromacy | Deutan model at maximum severity |
| `protanomaly` | Protanomaly | Reduced red-cone discrimination | Machado-type protan continuum; default intermediate severity |
| `protanopia` | Protanopia | Modeled red-cone dichromacy | Protan model at maximum severity |
| `tritanomaly` | Tritanomaly | Reduced blue-cone discrimination | Machado-type tritan continuum; default intermediate severity |
| `tritanopia` | Tritanopia | Modeled blue-cone dichromacy | Tritan model at maximum severity |
| `achromatomaly` | Achromatomaly | Reduced overall color discrimination | Adjustable desaturation / luminance blend, explicitly approximate |
| `achromatopsia` | Achromatopsia | Complete absence of perceived hue in a simplified model | Grayscale/luminance rendering, explicitly approximate |
| `normal` | Original colors | No transform | Identity matrix/pass-through |

**Terminology rule:** a general “effect intensity” slider that crossfades original and simulated frames is *not equivalent* to physiological deficiency severity. If both are offered, they must have different names and behavior.

**MVP default:** full model transform for `-opia` presets; documented intermediate model severity for `-omaly` presets. Offer a **simulation severity** slider for Machado-model classes and a distinct optional **compare blend** control (0–100% visual mix). For grayscale presets, label the slider **desaturation amount** or **approximation strength**, not physiological severity.

### 5.3 Controls

- Menu bar status item with show/hide, active preset, capture status, preferences, and quit.
- Compact lens toolbar/handle with preset picker, original/simulated toggle, pin/close, and resize affordance.
- Keyboard shortcuts configurable in settings; defaults to be selected after testing conflict risk.
- User can hide controls temporarily without removing the filter.
- Indicate capture-paused, permission-denied, and unsupported-frame states without showing stale content indefinitely.

### 5.4 Privacy and lifecycle

- No screenshot or pixel upload, analytics payload, recording, or local frame persistence by default.
- Stop ScreenCaptureKit stream when filtering is disabled for a sustained period or the lens is closed (exact policy can balance warm start against resources).
- If permission is revoked, stop capture, clear last frame, and show instructions to re-enable permission.
- On display disconnect, resolution/scaling change, sleep/wake, or Space transition, re-resolve display and capture geometry.

## 6. System architecture

```text
[Desktop / Underlying Applications]
                 |
                 v
 [ScreenCaptureKit display stream]
  - selected display
  - exclude utility's windows/app
  - pixel-buffer frames + timestamps
                 |
                 v
 [Frame + Geometry Coordinator]
  - current display / lens rectangle
  - screen -> capture texture coordinates
  - newest-frame policy
                 |
                 v
 [Metal Simulation Engine]
  - color-space decode/normalization
  - matrix model or achromatic transform
  - clipping/gamut handling
  - crop/texture lookup
                 |
                 v
 [MTKView in NSPanel]
  - filtered area aligned to screen
  - click-through interior
  - interactive controls/handles
                 |
                 v
 [Developer interacts with underlying app]
```

### Suggested Swift module boundaries

```text
ColorVisionLensApp/
  AppLifecycle/
    ApplicationCoordinator.swift
    PermissionsController.swift
  Capture/
    DisplayCaptureService.swift
    CaptureFrame.swift
    DisplayGeometry.swift
  Render/
    LensRenderer.swift
    CVDSimulation.metal
    SimulationModel.swift
    ColorSpacePipeline.swift
  Overlay/
    LensPanel.swift
    LensContentView.swift
    LensInteractionCoordinator.swift
  Preferences/
    PreferencesView.swift
    ShortcutManager.swift
  Tests/
    SimulationReferenceTests.swift
    GeometryTests.swift
    CaptureIntegrationTests.swift
```

The modules are suggestions, not a requirement for exact filenames.

## 7. Screen capture strategy

### 7.1 ScreenCaptureKit pipeline

1. Discover displays/shareable content via ScreenCaptureKit.
2. Choose the display currently hosting the lens.
3. Create an `SCContentFilter` for that display that excludes the utility's own process/windows where supported.
4. Start an `SCStream` with output frames suitable for direct CVPixelBuffer → Metal texture conversion (`CVMetalTextureCache`).
5. Receive frames on a dedicated queue; retain at most the newest actionable frame to avoid building a backlog.
6. Render frames in the lens at the display refresh cadence or when new frames arrive.
7. Stop and restart/reconfigure capture when the display target or significant configuration changes.

**Self-exclusion is mandatory.** The application should exclude its entire process from capture, including lens and settings windows, and separately verify that hidden/visible transitions cannot create feedback loops.

### 7.2 Full-display versus region-only capture

**Recommended MVP:** capture the selected display once, then crop/sample the relevant rectangle in Metal. This allows smooth lens movement without constantly restarting a stream; the cost is higher capture bandwidth.

**Optimization experiment:** capture just the lens rectangle with an `SCStreamConfiguration.sourceRect` (or equivalent supported region mechanism). This can reduce work, but lens movement and resizing may require repeated capture reconfiguration. Benchmark both strategies on representative Macs before choosing the production default.

### 7.3 Coordinate transformations

Keep explicit representations for:

- macOS global screen coordinates (points, possibly with negative origins across monitors).
- `NSScreen` frame and visible frame.
- backing pixels and `backingScaleFactor`.
- ScreenCaptureKit source/display coordinates and stream output pixel dimensions.
- Metal normalized UV coordinates.

Account for macOS' coordinate origin differences, display rotation, scaling, Retina backing, and the lens frame versus its content-area frame. Do **not** assume the window frame maps 1:1 to captured pixels.

Build a pure, unit-testable mapping function from `lensContentRectInScreenPoints` to `captureTextureRectInPixels`. Test left/top/right/bottom edges and mixed-scale display arrangements.

### 7.4 Multiple displays

For MVP, a lens belongs to a single selected display. If dragged across a boundary, either switch its capture source to the display containing most of the lens or constrain it to one display; prefer a predictable policy with visible feedback. Multi-display spanning and per-display stream stitching are post-MVP work.

## 8. Overlay / interaction model

- Use a borderless or titled `NSPanel`/`NSWindow` with an `MTKView` as the primary rendering surface.
- Keep the panel above ordinary windows; avoid relying on extreme system window levels that may interfere with system UI.
- Set the lens content to **ignore mouse events**, while providing a distinct interactive drag bar and resize targets. Since `ignoresMouseEvents` applies to an entire `NSWindow`, a practical implementation is either (a) separate click-through render and interactive control windows or (b) explicit `hitTest`/event-forwarding design that has been verified in practice. Simply setting `ignoresMouseEvents = true` on a single window would also disable its own controls.
- Overlay content must not become keyboard focus while a user is typing into the application beneath it unless controls are explicitly activated.
- Track window ordering / app switching where possible. A permanently floating filtered patch can obscure unrelated UI; offer a fast hide shortcut and consider an optional “show only when target window is active” mode later.
- The capture source excludes the overlay regardless of whether it is click-through.

## 9. Simulation mathematics and shader design

### 9.1 Model selection

For protan, deutan, and tritan families, use a **documented severity-varying model**, with Machado, Oliveira & Fernandes (2009) as the primary candidate. Implement its published matrices or another clearly documented reference implementation with provenance and validation.

For each selected model and severity:

1. Select the appropriate published tabulated transform(s).
2. Interpolate only as permitted/validated by the model specification.
3. Upload the 3×3 matrix as a Metal constant/uniform.
4. Apply the transform per pixel in the **correct model-defined RGB encoding/color space**.
5. Convert to the display output space, with a documented clipping/gamut strategy.

A conceptual matrix transform is:

```text
[R′ G′ B′]^T = M(type, severity) × [R G B]^T
```

Do **not** assume that directly multiplying arbitrary gamma-encoded sRGB, linear sRGB, or Display P3 values with the same coefficients gives a correct result. Validate the source model's RGB transfer function/primaries and explicitly convert input captured frames as needed.

### 9.2 Achromatic modes

- `achromatopsia`: convert to a luminance-derived grayscale image, preserving meaningful tone as far as possible; label as a **color-only approximation**.
- `achromatomaly`: blend the original with the grayscale result according to an adjustable desaturation factor. This is a **visual approximation**, not a validated physiological severity model.
- Document that symptoms beyond hue perception cannot be replicated by a color shader.

For a linear-light RGB representation, a typical Rec. 709/sRGB luminance calculation uses coefficients approximately `0.2126 R + 0.7152 G + 0.0722 B`. Convert between nonlinear encoding and linear light appropriately. The exact method is part of the renderer's color-management contract.

### 9.3 Shader structure

Prefer **one shared shader pipeline** with a small parameter buffer rather than eight separate GPU kernels:

```metal
// Illustrative fragment core only; full vertex/texture bindings omitted.
float3 applySimulation(float3 modelRGB,
                       constant float3x3& matrix) {
    return clamp(matrix * modelRGB, 0.0, 1.0);
}
```

Actual production shader stages should handle input texture sampling, crop coordinates, transfer functions, transforms, output encoding, alpha behavior, and orientation. Avoid including an arbitrary, unvalidated “color blindness RGB matrix” copied from a random blog post.

### 9.4 Reference quality

Maintain a CPU reference path (e.g., Swift test fixtures or Python-generated offline fixtures) containing the exact published matrices, known sample RGB inputs, expected outputs, and tolerances. A shader change must pass these comparisons before release.

## 10. Rendering, latency, and performance

### Targets (to be validated, not guarantees)

| Metric | Proposed MVP target |
|---|---|
| Usable refresh | At least 30 fps on supported baseline Macs |
| Preferred refresh | 60 fps when display/capture allows |
| Added capture-to-photon delay | Aim below ~50 ms on a representative Apple silicon Mac |
| Frame queue | Latest-frame-wins; no unbounded buffering |
| Resize/move interaction | Responsive without frequent capture restarts |
| CPU use | Low steady-state overhead; benchmark and set a budget |
| Memory | Bounded pixel buffer and texture pool |

Instrument timestamps for capture receipt, texture availability, render encoding, GPU completion, and presentation. Report median and p95 latency separately. Test animation, rapid scrolling, text input, and window movement—not just static scenes.

### Performance principles

- Reuse Metal pipeline state and buffers.
- Avoid CPU pixel copies and PNG/JPEG encoding.
- Use `CVMetalTextureCache` when possible.
- Limit in-flight frames and drop stale frames.
- Recalculate matrices only when type/severity changes.
- Render only while lens is visible and capture is authorized.
- Investigate HDR/EDR and high-refresh monitors after SDR quality is stable.

## 11. UX behavior and accessibility of the tool itself

### Default flow

1. Launch menu bar app.
2. Explain and request Screen Recording permission.
3. Show the lens in the center of the active display.
4. Default to deuteranopia or the last selected mode.
5. Drag with the title bar; resize from corners/edges.
6. Choose mode and adjust supported severity.
7. Hold a compare shortcut or use a toggle for original colors.
8. Hide/quit from menu bar or shortcut.

### UI principles

- Lens controls must remain visually unaffected by the simulation, or at least clearly labeled and accessible.
- Provide text labels, not only colored swatches.
- Ensure keyboard access and VoiceOver labels for all controls.
- Clearly distinguish **simulation severity**, **desaturation**, and **blend with original**.
- Make capture state visible and provide a prominent stop/quit affordance.

## 12. Validation and test plan

### 12.1 Unit tests

- Identity mode matches source within an appropriate pixel tolerance.
- All eight preset identifiers resolve to the expected algorithms.
- Published model matrices/fixtures match a validated CPU reference across severity steps.
- Monochrome neutrals do not gain an unjustified hue cast.
- Achromatopsia output channels are equal within tolerance.
- `achromatomaly` moves monotonically toward grayscale as desaturation increases.
- Deterministic geometry mapping under 1×, 2×, mixed scale and negative desktop origins.
- Color transfer and gamut clipping behavior matches declared assumptions.

### 12.2 Integration tests

- Screen Recording permission grant, denial, revocation, and relaunch.
- No recursive image when lens overlaps itself or any owned settings window.
- Scroll underlying browser/Simulator while lens content is click-through.
- Resize rapidly and move the lens between edges of the screen.
- Sleep/wake, monitor disconnect/reconnect, resolution/rotation changes, Spaces/fullscreen transitions.
- Protected content shows an appropriate fallback; do not claim it is filtered.
- Retina and non-Retina displays, SDR and (later) HDR.
- Tool controls remain accessible by pointer and keyboard.

### 12.3 Empirical benchmark matrix

At minimum: a baseline Apple silicon laptop, a newer Apple silicon laptop, a built-in Retina screen, and an external monitor. Measure 30/60 fps behavior, p50/p95 latency, memory use, and CPU/GPU impact with animated apps. Test Xcode Simulator/Device Hub, Android Emulator, Safari/Chrome, and a design application.

### 12.4 Human evaluation

This is a **simulation of color differences**, not a diagnostic or substitute for testing with people who have color vision deficiencies. If the utility is later marketed for accessibility decisions, recruit participants with a range of CVD experiences and involve an accessibility specialist in interpretation.

## 13. Error handling and edge cases

| Condition | Expected behavior |
|---|---|
| Permission not granted | No capture; explain exact setup action and allow retry |
| Capture interrupted | Freeze for a very short bounded period, then clear/show paused state |
| Lens moved to unsupported display | Switch or constrain under published policy; never silently misalign |
| App captures its own window | Treat as a critical bug; exclusion and regression tests required |
| HDR/wide-gamut unsupported | Explicit SDR conversion and visible limitation rather than inaccurate implicit transform |
| Computer under GPU load | Drop stale frames, preserve interactivity, optionally reduce capture rate |
| Secure/DRM content | Respect platform restrictions; do not attempt bypass |
| OS/API behavior changes | Fail gracefully, log non-sensitive diagnostics, document supported versions |

## 14. Security and privacy requirements

- Screen capture remains on-device for this product's core functionality.
- No cloud service is needed for the MVP.
- No screenshots persisted unless the user explicitly requests export in a future release.
- Avoid logging frame contents, window titles, or application data unnecessarily.
- Provide a clear permission disclosure and direct stop-capture action.
- Any future analytics must be opt-in and contain no visual frame content.

## 15. Compatibility and API spike

Before full implementation, verify these questions on the minimum supported macOS version:

1. Does ScreenCaptureKit reliably exclude the utility application while a floating panel overlaps the source display?
2. What is the exact display/content coordinate behavior for `SCStreamConfiguration.sourceRect` versus full-display cropping?
3. Can a full-display stream be processed at the required rate without unacceptable overhead on the baseline Mac?
4. Which pixel formats and color-space metadata are delivered for SDR and EDR displays?
5. Can the overlay show a click-through filtered interior and still provide reliable interactive resize handles?
6. How do Space changes, fullscreen mode, and multiple displays affect overlay visibility and alignment?
7. What permissions, code-signing, sandboxing, and notarization behavior apply to the intended distribution route?

These are validation tasks, not assumptions already proven by this specification.

## 16. Delivery plan

### Phase 0 — Feasibility spike

**Deliverable:** a single movable lens over one display, using live capture, a trivial invert/grayscale Metal effect, and self-exclusion.

**Exit criteria:** no feedback loop; usable click-through; correct pixel alignment; measured latency under interaction.

### Phase 1 — MVP engine

- Full-display capture with newest-frame policy.
- Metal renderer and color-space contract.
- Eight presets plus original mode.
- Machado-family matrix lookup and severity behavior.
- Achromatic approximation modes.
- Reference fixtures and numerical tests.

**Exit criteria:** all presets produce tested deterministic results; no unexpected tint on neutral input; acceptable baseline performance.

### Phase 2 — Developer-friendly utility

- Menu bar integration and polished panel controls.
- Shortcuts, persistence, permission states.
- Better drag/resize behavior and display-change recovery.
- Performance dashboard for internal QA.

**Exit criteria:** a developer can inspect Simulator, browser, and design tooling for a full session without restarting the app.

### Phase 3 — Quality / release

- Hardware/monitor test matrix.
- Privacy documentation and onboarding.
- Signed, notarized distributable.
- Public algorithm documentation and known limitations.

### Future extensions

- Multiple simultaneous lenses with different presets.
- Side-by-side original versus simulated snapshots.
- Region-only capture optimization.
- Fullscreen simulation.
- Screenshot import/export and accessibility issue annotation.
- Optional repository/source analysis and CI integration.

## 17. Acceptance criteria for first public beta

- [ ] User can install and launch a signed build on supported macOS.
- [ ] Permission onboarding works and revocation is handled cleanly.
- [ ] Lens moves and resizes over arbitrary visible applications on one monitor.
- [ ] Pointer input passes through the lens content; handles and toolbar remain usable.
- [ ] Capture excludes the lens and all owned windows, with no recursive feedback.
- [ ] All eight requested presets and original mode are selectable.
- [ ] Cone-related simulations use a documented model and pass reference image tests.
- [ ] Achromatic modes are explicitly labeled as approximations.
- [ ] Rendering remains perceptually responsive during scrolling on the baseline test system.
- [ ] Correct alignment and pixel scaling on a Retina display.
- [ ] Frame capture never uploads or stores image data by default.
- [ ] Known technical and physiological limitations are available in-app.

## 18. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Capture-to-display latency | High | Benchmark immediately; avoid CPU round-trips; latest-frame policy |
| Incorrect color science | High | Published model, reference fixtures, explicit color-space handling |
| Broken click-through controls | Medium–high | Separate render and controls windows if necessary |
| Capture recursion | High | Exclude process/windows and regression test overlap |
| Multi-monitor mismapping | Medium | Single-display MVP and geometry unit tests |
| Excessive capture bandwidth | Medium | Test ROI capture after correctness and responsiveness are achieved |
| Misleading achromatopsia claims | High | Label approximations and explain non-color symptoms |
| OS-level restrictions and privacy expectations | Medium | Clear consent, graceful fallback, no frame persistence |
| Licensing provenance of matrix sets | Medium | Implement from properly licensed/publicly documented scientific reference; audit source licenses |

## 19. Related work, research, and references

- **Colorblinds** (architecture and implementation reference): https://github.com/jdekock/Colorblinds — verify exact code paths, coefficients, supported platforms and licensing against the repository revision actually used. Do not assume its shader matrices are scientifically validated without checking.
- **Machado, Oliveira & Fernandes (2009)**, *A Physiologically-based Model for Simulation of Color Vision Deficiency*: https://pubmed.ncbi.nlm.nih.gov/19834201/ — primary candidate for protan/deutan/tritan severity-aware simulation.
- **Apple ScreenCaptureKit documentation:** https://developer.apple.com/documentation/screencapturekit
- **Apple Metal documentation:** https://developer.apple.com/metal/
- **Apple AppKit NSWindow documentation:** https://developer.apple.com/documentation/appkit/nswindow
- **WCAG 2.2 — Use of Color:** https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html — background on the accessibility problem, not a certification mechanism for the lens.

### Reference and implementation caveat

This specification includes **architectural recommendations and hypotheses** rather than a claim that every API interaction has been prototyped. Verify Colorblinds' source revision, published matrix coefficients, source-model transfer-function requirements, ScreenCaptureKit capture behavior, and macOS distribution limitations during Phase 0 before freezing the implementation.

## 20. Open decisions

1. Exact minimum macOS version (proposed 14+).
2. Lens visual appearance: thin border only versus small toolbar.
3. Keyboard shortcut defaults and conflict handling.
4. Whether the initial anomaly severity is 50%, another published reference value, or chosen interactively at first launch.
5. Separate compare-blend slider versus only press-and-hold original preview.
6. Whether moving across displays switches capture automatically or constrains the lens.
7. Default color pipeline for mixed Display P3 and SDR inputs.
8. Direct distribution first versus Mac App Store.
9. Whether to add screenshot export to the first beta (default: no).

---

**Recommended immediate next action:** implement the Phase 0 proof of concept with ScreenCaptureKit, `MTKView`, and a draggable click-through overlay, measure latency, and validate self-exclusion before investing in the full model library or polished UI.
