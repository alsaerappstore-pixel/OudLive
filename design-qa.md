# Native iPhone design review — 3.16

Selected references: interface-concepts/01-eighties.png, 02-nineties.png and 05-modern.png. These are the user's three named selections, not the third generated option (simple performance).

Runtime: existing native SwiftUI app, Arabic RTL. The three layouts share AudioModel and recordings. iOS owns the system status bar and safe areas. SF Symbols and the existing oud images are reused; a generated walnut texture supplies the eighties background.

First simulator review: work/preview316final/{eighties,nineties,modern}-preview.png, captured from run 38336080449. App screenshots are 430 pixels wide and include native system chrome; concepts exclude it. Compare app content, not the system margins. Images are distinct design directions rather than a pixel-identical web recreation.

P2 finding: the expanded connection panel pushed fader values below the initial viewport. Fix: collapse connection details and explanatory copy into a disclosure; retain the live listening button and route picker. Rebuild and new captures required.

Review scope: Arabic type legibility, header and transport spacing, nickel/dark channel distinction, walnut and oud asset quality, real rather than invented control values, access to all previous services. The nineties interface uses stacked rotary racks; the other two use faders. All layouts scroll for secondary functions and retain the fixed recording transport and navigation.

Hardware routing and touch interactions require an iPhone follow-up. Simulator launches and images alone are not evidence of physical Bluetooth behavior.

Post-fix evidence: work/preview316compact/{eighties,nineties,modern}-preview.png from successful run 38373593533. Four fader labels, tracks and values now fit above the fixed transport in eighties and modern. Nineties racks continue vertically by scrolling, intentionally retaining readable touch targets. Arabic text, distinct materials, oud imagery and persistent transport reviewed. Remaining P3: the nineties small monitor caption uses monospaced Arabic; simplify typography in a later polish pass. The effect-detail/library screens retain shared established components rather than matching every decorative detail of the concepts.

final result: passed
Visual review scope only; physical routing and touch interaction verification remain explicitly untested.
