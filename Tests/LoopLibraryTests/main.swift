import Foundation
let suite = "OudLive-tests-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let data = try JSONEncoder().encode([
    UserLoop(id: "a", name: "A", group: "G", file: "a.wav", playable: true, duration: 1),
    UserLoop(id: "b", name: "B", group: "G", file: "b.wav", playable: true, duration: 2),
    UserLoop(id: "x", name: "X", group: "G", file: "x.rx2", playable: false, duration: 0)
])
var library = LoopLibrary(data: data, defaults: defaults)
precondition(library.slots.count == 5 && library.slots.allSatisfy(\.isEmpty))
let a = library.items[0], b = library.items[1], x = library.items[2]
library.assign(a, to: 0); library.assign(a, to: 1); library.assign(b, to: 4)
library.assign(x, to: 2); library.assign(a, to: 8)
library.rename(a, name: "  سامري  ")
library = LoopLibrary(data: data, defaults: defaults)
precondition(library.slot(0)?.id == "a" && library.slot(4)?.id == "b" && library.slot(2) == nil)
precondition(library.title(a) == "سامري")
library.assign(b, to: 0); library.assign(nil, to: 4)
precondition(library.slot(0)?.id == "b" && library.slot(4) == nil)
library.delete(a)
library = LoopLibrary(data: data, defaults: defaults)
precondition(library.items.count == 2 && library.slot(1) == nil && library.slot(0)?.id == "b")
library.assign(a, to: 3); precondition(library.slot(3) == nil)
library.restoreDeleted(); library = LoopLibrary(data: data, defaults: defaults)
precondition(library.items.count == 3 && library.slot(1) == nil && library.title(a) == "سامري")
defaults.set(["missing", "a", "x", "b", "a", "b"], forKey: "OudLive.loopSlots.v1")
library = LoopLibrary(data: data, defaults: defaults)
precondition(library.slots == ["", "a", "", "b", "a"])
print("PASS five persistent slots, replace/clear, rename, delete clears references, restore, stale/unsupported IDs")
