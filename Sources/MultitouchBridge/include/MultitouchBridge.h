// Minimal bridge to Apple's private MultitouchSupport framework, the only way to read
// trackpad touches outside one's own windows. Loaded at runtime with dlopen.
#ifndef MULTITOUCH_BRIDGE_H
#define MULTITOUCH_BRIDGE_H

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position; MTPoint velocity; } MTVector;

/// One finger on the trackpad. Layout as reverse-engineered by MiddleClick, Jitouch and others.
typedef struct {
    int frame;
    double timestamp;
    int identifier;
    int state;
    int fingerID;
    int handID;
    MTVector normalized;  // position in 0...1 on both axes
    float size;
    int zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolute;
    int zero2[2];
    float density;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTFrameCallback)(MTDeviceRef device, const MTTouch *touches, int count, double timestamp, int frame);

/// (Re)starts every multitouch device with `callback`, called on a background thread for every frame.
/// Returns the number of devices started, or -1 when the framework cannot be loaded.
int MTBridgeStart(MTFrameCallback callback);

/// Stops every device started by MTBridgeStart.
void MTBridgeStop(void);

#endif
