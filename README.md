# ChromaLens

A macOS menu bar app that puts a movable lens over your screen and shows what's
beneath it the way it may look to someone with a color vision deficiency.

Drag the lens over a simulator, a browser or a design tool and compare. The app
underneath needs no integration: ChromaLens captures the region under the lens,
transforms it on the GPU and draws it back in place. Clicks and scrolling inside
the lens go straight through to the app below.

## What it does

- **Eight simulations plus original colors**: deuteranomaly, deuteranopia,
  protanomaly, protanopia, tritanomaly, tritanopia, achromatomaly and
  achromatopsia.
- **A documented model.** Protan, deutan and tritan simulations use the
  published matrices from Machado, Oliveira & Fernandes (2009), applied in
  linear sRGB. The *-anomaly* presets have a severity slider (10–90%); the
  *-anopia* presets use full severity. The two achromatic modes are labeled
  approximations.
- **Compare quickly.** A blend-with-original slider, a toolbar toggle, and a
  hold-to-compare shortcut.
- **Stays out of the way.** Hide the toolbar and border and keep only a thin
  outline. The lens follows you across Spaces, including over full-screen apps.
- **Global shortcuts**, configurable in Settings: ⌃⌥⌘L show/hide, ⌃⌥⌘O hold for
  original, ⌃⌥⌘] / ⌃⌥⌘[ next/previous simulation, ⌃⌥⌘H show/hide controls.
- **Help that teaches.** An in-app guide to color vision deficiency and each
  type, design guidance, and the model's limitations.

## Privacy

ChromaLens needs Screen Recording permission. It captures only the area around
the lens and excludes its own windows. Frames stay in memory; nothing is saved
or sent anywhere. **Stop Capture** in the menu bar stops it immediately.

## Requirements

macOS 26 or later. Apple silicon is the primary target.

## Building

The Xcode project is generated from `XcodeProject.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen). After changing the spec:

```sh
xcodegen generate --spec XcodeProject.yml
```

Open `ChromaLens.xcodeproj` and run the **ChromaLens (Debug)** scheme, or:

```sh
xcodebuild -project ChromaLens.xcodeproj -scheme "ChromaLens (Debug)" -destination 'platform=macOS' build
```

Debug builds are signed with an Apple Development certificate (team
`CQXRBQKG85`, set in `XcodeProject.yml`). A stable signature matters here:
macOS ties Screen Recording permission to the code signature, so ad-hoc builds
lose it on every rebuild. To build with your own account, change
`DEVELOPMENT_TEAM` and regenerate the project.

Release builds are archived, notarized and published with
`scripts/build-and-notarize.sh`, with updates delivered through Sparkle.

## Tests

The simulation math lives in `Packages/ColorVisionKit` and tests on its own:

```sh
cd Packages/ColorVisionKit && swift test
```

The tests check the published matrices, neutral-gray preservation, fixed color
fixtures, lens geometry across mixed-scale and negative-origin displays, and
compile the app's Metal shader to confirm the GPU output matches the CPU
reference.

## Project layout

```
ChromaLens/macOS/
  AppLifecycle/     LensCoordinator: lens state, capture lifecycle, recovery
  Capture/          ScreenCaptureKit region capture and permission handling
  Render/           Metal renderer and CVDSimulation.metal
  Overlay/          Lens panels, toolbar, border handles, status overlay
  Shortcuts/        Carbon global hot keys and the shortcut recorder
  Menu Bar Button/  Menu bar item and popup
  Onboarding/       Screen Recording onboarding
  Help Window/      Help.md and its window
Packages/ColorVisionKit/   Presets, Machado model, color transfer, geometry
Docs/                      Product specification
```

## Limitations

- Standard color range only: wide-gamut and HDR colors are converted to sRGB
  before simulation.
- One display at a time; the lens can't span displays.
- Content that macOS protects from capture may appear blank in the lens.
- The lens shows a captured copy, so it trails live content by a frame or two.
- It's a simulation of color differences, not a diagnostic tool, and it can't
  show non-color symptoms such as the light sensitivity that comes with
  achromatopsia.

## License

ChromaLens is released under the BSD Zero Clause License; see `LICENSE`. The
Machado matrices come from the colour-science dataset (BSD-3-Clause); see the
in-app Attributions window.
