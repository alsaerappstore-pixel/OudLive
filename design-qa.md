# Native iPhone design comparison — OudLive 3.0

final result: passed

Post-fix simulator captures have been compared side by side and in focused regions. The first compiled UI had a P2 density issue: a tall status panel, separate source selector, and 20-point vertical gaps pushed the simple preset bank and stage switches below the first viewport. The updated implementation compacts the status panel and spacing, moves the source picker into the current-sound row, and places the six stage switches in a three-column bank. No sound processing changes are involved.

## Evidence and normalization

Source concepts: `C:/Users/Admin/.codex/generated_images/01a0ed91-b8ef-7af1-a597-f674135052c1/exec-3bf56605-47c4-47e7-ab4d-714bf89c6075.png` (studio), `exec-5b963c59-0828-4d7f-b0ca-b0cdf6d4915a.png` (simple), `exec-75833169-93c2-4538-bf05-5e56f5a5489e.png` (stage).

Each source is 853 × 1844; downsampled to width 430 for comparison. Actual simulator captures are 430 × 935, downsampled by the simulator script. These are native iOS points/pixels, not a web CSS viewport. The concepts omit OS chrome, which remains in actual captures and is excluded from content-spacing judgments. Exact logical device dimensions can be obtained from the workflow device metadata; they were not asserted from the downsampled image.

First evidence: `work/compare-studio-before.png`, `work/compare-simple-before.png`, `work/compare-stage-before.png` show concept and actual side by side at matching width. State: idle microphone, persisted default natural preset, no recording. The concepts show active signal and different selected presets; idle/unselected state differences are expected and not fidelity defects. Audio lights are deliberately dark at silence.

## Required surfaces

- Typography: native Arabic system type and SF Symbols keep legibility. Title, selected sound, labels, numerical values, and captions have distinct weights and sizes. First captures had no text collisions, but excess vertical separation was actionable.
- Spacing: first P2 density issue and fix described above. Fixed transport remains visible; content scrolls within its safe area. Secondary controls remain scrollable rather than shrinking touch targets.
- Colors: copper/charcoal studio, ivory/forest simple, cyan/navy stage follow the three concepts. Active/disabled states remain distinguishable without relying on glow alone.
- Images: no decorative bitmap assets are needed. Dials, LEDs and stomp buttons are functional native controls; photorealistic textures from the concept are intentionally simplified. OS status bar and home indicator are real, not painted into app content.
- Copy: invented phantom-power and independent L/R readings in the generated concept are omitted. The app shows actual input/record/headphone peaks. Bluetooth latency and headphone-free recording copy matches implemented behavior.

## Interaction checks and limits

Native iPhone Release build, simulator Debug launch, 19 DSP checks, WAV output, settings migration and MP4 export passed on the first revision. Source inspection verifies every layout calls the same audio model and recording view, with persistent theme choice. The simulator screenshot smoke test does not simulate knob drags, VoiceOver, arbitrary Dynamic Type sizes, photo permission denial, or a real save into the user's Photos library. These remain device validation steps; no browser console applies to this native app.

## Implementation checklist

- Obtain and inspect post-fix full captures and focused control regions.
- Keep all audio, video, file actions and settings available in every theme.
- Verify a short video save to Photos on the installed iPhone after permission is granted.


## Post-fix comparison and final disposition

Run 37074672948 completed successfully at commit f928e7f2c961f976072c851f0376b3d4477b059b. Evidence: outputs/OudLive-studio.png, outputs/OudLive-simple.png, outputs/OudLive-stage.png; paired comparisons work/compare-studio.png, work/compare-simple.png, work/compare-stage.png. Focused paired control-region evidence: work/focus-simple.png and work/focus-stage.png. Additional actual screens: outputs/OudLive-effects.png and outputs/OudLive-recording.png.

The earlier P2 density issue is resolved: all four simple preset buttons are visible above transport; studio exposes its four rotary controls; stage exposes both rows of its six-switch bank, with lower descriptions continuing in the scroll area. Numeric values and secondary controls below the fold remain intentionally scrollable. Native status-bar space, persistent original-sound comparison, and retained page navigation account for remaining concept-to-app density differences. No persistent control is hidden or overlaps another persistent control.

Focused review confirms Arabic names, SF Symbols, distinct headings and labels, regular column spacing, and legible values. Palette and structure match the intended three directions. The design is an adaptation to a functional native app, not a pixel-identical reproduction of generated control textures. No actionable P0/P1/P2 findings remain in the captured states. P3: a future compact-meter option could expose more secondary controls without scrolling.

Photos button interaction, device camera/audio, active-light motion, and maximum Dynamic Type remain untested on hardware. The recording screenshot is the empty-library initial state, so it does not provide visual evidence for populated recording rows or the Photos button. The release compiles these controls, but this report does not claim a Photos export was executed.
