# Native iOS design comparison — OudLive 3.5

## Reference and scope

User-selected screenshot: `codex-clipboard-ddd40756-037b-44bf-9a9e-38a97881c684.png` (2227 × 1468). Native SwiftUI implementation, not a website. The reference and an actual simulator capture were inspected together. The comparison is a responsive adaptation, not a claim of pixel identity across a desktop and an iPhone viewport.

## Five-surface review

| Surface | Reference | Implementation and decision |
|---|---|---|
| Typography | White Arabic heading, smaller gray labels, prominent recording action | Native Arabic system type, bold title and recording label, smaller secondary descriptions; RTL text remains legible in the inspected portrait and effect-detail views. |
| Layout | Header, input/oud/camera columns, bottom effect rack | Three columns in landscape; stacked cards and a two-column rack in portrait. Vertical scrolling retains usable controls on a phone. Files/settings open native sheets. |
| Color | Charcoal panels, red recording, colored effect rings | Dark surfaces and borders, red recording, blue input/output, violet reverb, green delay, blue chorus, copper compression, rose doubler. |
| Imagery | Large warm oud photograph and live player camera | Generated photographic oud asset, warm background, dark space behind presets. Camera area is an honest inactive state until permission and actual capture are available. No fake live video. |
| Copy and controls | Arabic recording menu, presets, effect names, knobs and switches | Arabic labels, existing 15 distinct presets, rotary controls with parameter values, independent effect switches, detailed explanations, recordings and memories. |

## Intentional differences

- Desktop minimize/maximize/close controls are omitted on iPhone.
- EQ exposes the engine's actual three bands; the mockup's five bands are not represented by nonfunctional dials.
- The pause-looking camera control is replaced with a labeled monitoring mute control. Recording supports start/stop; pause/resume within a recording is not implemented.
- The wide rack scrolls horizontally because its full desktop width does not fit a phone; the overall page scrolls vertically. Portrait exposes all sections by vertical scrolling.
- Camera preview is aspect-fit, preserving the frame rather than cropping to fill. It starts with the front camera, with camera switching before recording.
- Existing themes remain available through Settings. Saved sounds and recordings use their existing models and storage keys.
- Following the user's additional request, a live-listening panel precedes the hero. It selects the phone/USB mic or a Bluetooth headset mic and starts monitoring independently of recording. The landscape variant is compact. This is an intentional addition beyond the reference.

## Verification boundary

Release and simulator builds plus DSP, persistence, recording and media-export tests run in GitHub Actions. Screenshot review verifies visible rendering, not every gesture or permission flow. Physical camera framing, Photos permissions/save, Bluetooth delay and recording synchronization must be checked on a real iPhone. No hardware test is claimed.

## Final capture review

Verified run: https://github.com/alsaerappstore-pixel/OudLive/actions/runs/37325294798
Source commit: `818af85a392db0d530559786ad3602fe9e7b51c8`.

Inspected portrait, landscape, scrolled effect rack, reverb details, sound memories, empty recording library, and retained 1980s studio layout. The main screenshots show the independent listening button and microphone selector without overlap; the landscape composition retains the input/oud/camera order. The scrolled rack shows distinct colored rings and power switches. Details retain Arabic descriptions and numeric values. The eight memory slots and empty-state library remain available. Main screen camera is intentionally inactive on the simulator.

Outcome: the visual adaptation is accepted for this release, with the deliberate phone scrolling and native differences above. This is not a pixel-perfect desktop reproduction, a VoiceOver audit, or an end-to-end tap test. Some modal captures caught presentation transitions, so toolbar behavior is not asserted from those images. Build diagnostics contain existing deprecation and Swift 6 migration warnings; current Swift 5 builds and all checks pass.
