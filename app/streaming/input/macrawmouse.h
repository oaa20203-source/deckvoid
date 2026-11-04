#pragma once

// Raw mouse motion on macOS through GameController's GCMouse, the way
// VoidLink does it. SDL's relative mode on macOS takes motion from the AppKit
// event queue on the main thread, where it is coalesced, pointer-accelerated
// and delayed behind everything else the main loop does. GCMouse delivers
// every HID report on its own high-priority queue, and we send it to the host
// from there with no main-thread hop.
namespace MacRawMouse {

// Start forwarding raw relative motion to the host (call when relative
// mouse capture becomes active).
void start();

// Stop forwarding (call when capture ends or the session closes).
void stop();

// True while GCMouse is actively delivering motion, so SDL's motion
// events for the same movement must be ignored.
bool isForwarding();

}
