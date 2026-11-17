#include "MultitouchBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdbool.h>

typedef CFMutableArrayRef (*CreateListFunction)(void);
typedef void (*CallbackFunction)(MTDeviceRef, MTFrameCallback);
typedef void (*StartFunction)(MTDeviceRef, int);
typedef void (*StopFunction)(MTDeviceRef);

static CreateListFunction createList;
static CallbackFunction registerCallback;
static CallbackFunction unregisterCallback;
static StartFunction startDevice;
static StopFunction stopDevice;

static CFArrayRef devices;
static MTFrameCallback activeCallback;

static bool load(void) {
    if (createList) return true;
    void *handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY);
    if (!handle) return false;
    CreateListFunction create = (CreateListFunction)dlsym(handle, "MTDeviceCreateList");
    registerCallback = (CallbackFunction)dlsym(handle, "MTRegisterContactFrameCallback");
    unregisterCallback = (CallbackFunction)dlsym(handle, "MTUnregisterContactFrameCallback");
    startDevice = (StartFunction)dlsym(handle, "MTDeviceStart");
    stopDevice = (StopFunction)dlsym(handle, "MTDeviceStop");
    if (!create || !registerCallback || !unregisterCallback || !startDevice || !stopDevice) return false;
    createList = create;
    return true;
}

void MTBridgeStop(void) {
    if (!devices) return;
    for (CFIndex i = 0; i < CFArrayGetCount(devices); i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(devices, i);
        unregisterCallback(device, activeCallback);
        stopDevice(device);
    }
    CFRelease(devices);
    devices = NULL;
    activeCallback = NULL;
}

int MTBridgeStart(MTFrameCallback callback) {
    if (!load()) return -1;
    MTBridgeStop();
    devices = createList();
    if (!devices) return 0;
    activeCallback = callback;
    CFIndex count = CFArrayGetCount(devices);
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(devices, i);
        registerCallback(device, callback);
        startDevice(device, 0);
    }
    return (int)count;
}
