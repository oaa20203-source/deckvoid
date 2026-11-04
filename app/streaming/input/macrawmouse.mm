#include "macrawmouse.h"

#include <Limelight.h>
#include <SDL.h>

#include <atomic>

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>

namespace {

// Same scale as VoidLink so raw counts feel like its pointer speed.
constexpr float kMouseSpeedDivisor = 1.25f;

// SDL motion is ignored while raw motion arrived within this window.
constexpr Uint32 kForwardingWindowMs = 250;

std::atomic<bool> s_Active{false};
std::atomic<Uint32> s_LastMotionMs{0};
std::atomic<bool> s_HasMotion{false};
dispatch_queue_t s_Queue = nullptr;
id s_ConnectObserver = nil;

// Only touched on s_Queue
float s_AccumX = 0;
float s_AccumY = 0;

void attachMouse(GCMouse* mouse) API_AVAILABLE(macos(11.0))
{
    mouse.handlerQueue = s_Queue;
    mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput*, float deltaX, float deltaY) {
        if (!s_Active.load(std::memory_order_relaxed)) {
            return;
        }

        s_LastMotionMs.store(SDL_GetTicks(), std::memory_order_relaxed);
        s_HasMotion.store(true, std::memory_order_relaxed);

        // GCMouse reports +Y as up; the host expects +Y as down.
        s_AccumX += deltaX / kMouseSpeedDivisor;
        s_AccumY += -deltaY / kMouseSpeedDivisor;

        short x = (short)s_AccumX;
        short y = (short)s_AccumY;
        if (x != 0 || y != 0) {
            LiSendMouseMoveEvent(x, y);
            s_AccumX -= x;
            s_AccumY -= y;
        }
    };
}

void detachMouse(GCMouse* mouse) API_AVAILABLE(macos(11.0))
{
    mouse.mouseInput.mouseMovedHandler = nil;
}

}

namespace MacRawMouse {

void start()
{
    if (@available(macOS 11.0, *)) {
        if (s_Active.exchange(true)) {
            return;
        }

        if (s_Queue == nullptr) {
            dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                                 QOS_CLASS_USER_INTERACTIVE, 0);
            s_Queue = dispatch_queue_create("DeckVoidRawMouse", attr);
        }

        s_HasMotion.store(false);
        dispatch_async(s_Queue, ^{
            s_AccumX = s_AccumY = 0;
        });

        for (GCMouse* mouse in GCMouse.mice) {
            attachMouse(mouse);
        }

        s_ConnectObserver = [[[NSNotificationCenter defaultCenter] addObserverForName:GCMouseDidConnectNotification
                                                                               object:nil
                                                                                queue:[NSOperationQueue mainQueue]
                                                                           usingBlock:^(NSNotification* note) {
            if (s_Active.load()) {
                attachMouse((GCMouse*)note.object);
            }
        }] retain];

        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "Raw mouse input: forwarding GCMouse motion (%lu mice)",
                    (unsigned long)GCMouse.mice.count);
    }
}

void stop()
{
    if (@available(macOS 11.0, *)) {
        if (!s_Active.exchange(false)) {
            return;
        }

        if (s_ConnectObserver != nil) {
            [[NSNotificationCenter defaultCenter] removeObserver:s_ConnectObserver];
            [s_ConnectObserver release];
            s_ConnectObserver = nil;
        }

        for (GCMouse* mouse in GCMouse.mice) {
            detachMouse(mouse);
        }

        s_HasMotion.store(false);
    }
}

bool isForwarding()
{
    return s_Active.load(std::memory_order_relaxed) &&
           s_HasMotion.load(std::memory_order_relaxed) &&
           SDL_GetTicks() - s_LastMotionMs.load(std::memory_order_relaxed) < kForwardingWindowMs;
}

}
