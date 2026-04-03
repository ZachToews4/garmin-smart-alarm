# Garmin Simulator Runtime Debug — Ubuntu 24.04 Host

## Problem
Garmin Connect IQ simulator fails immediately on this host with:

`libsoup-ERROR **: libsoup2 symbols detected. Using libsoup2 and libsoup3 in the same process is not supported.`

## What was verified

### Direct dependency inspection
`ldd /home/zach/garmin/sdk/bin/simulator` shows the simulator binary links directly to:
- `libsoup-2.4.so.1`
- `libwebkit2gtk-4.0.so.37`

The same resolved dependency tree also brings in:
- `libsoup-3.0.so.0`

This means the process ends up with both libsoup major versions in one address space.

### Binary string check
The simulator binary itself references:
- `libsoup-2.4`
- `webkit2gtk-4.0`

It does **not** directly reference libsoup3 by name; libsoup3 is arriving through newer host libraries.

### Runtime tracing
`LD_DEBUG=libs` confirms `libsoup-3.0.so.0` gets initialized before the crash, after which the simulator aborts with the libsoup mixed-major error.

### Environment-based mitigation attempts tried
No success with:
- forcing `DISPLAY=:99`
- `GDK_BACKEND=x11`
- `WEBKIT_DISABLE_COMPOSITING_MODE=1`
- clearing `LD_LIBRARY_PATH`
- clearing `GI_TYPELIB_PATH`
- setting `GIO_MODULE_DIR=/nonexistent`
- clearing `GTK_PATH` / `GTK_MODULES`
- `GSETTINGS_BACKEND=memory`
- `GIO_USE_VFS=local`

Conclusion: this is not a simple environment-variable contamination issue.

## External confirmation
Garmin forum report indicates Ubuntu 24.04 users are hitting the same libsoup2/libsoup3 crash in Garmin SDK components.

## Current conclusion
This looks like an upstream Garmin SDK compatibility issue on modern Ubuntu rather than an app-specific bug.

## Practical implications
- The app can still be built successfully with `monkeyc`.
- The local simulator path is currently not a trustworthy validation route on this host.
- Best available validation paths right now are:
  1. replay harness with real public sleep data
  2. direct watch-side validation on actual hardware
  3. running the Garmin simulator in an older/containerized userspace if desired later

## Most likely next workaround paths
1. Run simulator from an older Ubuntu/Jammy-compatible container or VM.
2. Test directly on a physical Venu 2.
3. Investigate whether Garmin has a newer SDK build that removes the mixed libsoup dependency chain.
