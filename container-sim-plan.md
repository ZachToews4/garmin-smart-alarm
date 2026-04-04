# Containerized Garmin Simulator Plan

## Goal
Run the Garmin Connect IQ Venu 2 simulator in an older Linux userspace/container so the app UI can be verified despite the host Ubuntu 24.04 libsoup conflict.

## Success tests
1. A container/userspace launches the Garmin simulator without the libsoup2/libsoup3 crash.
2. `monkeydo` can deploy `bin/smart-alarm.prg` into that simulator.
3. A screenshot can be captured from the Venu 2 simulator.
4. The screenshot is good enough to evaluate layout issues.

## Constraints
- Prefer local/containerized workaround over full VM if possible.
- Keep changes reversible.
- Avoid breaking the host Garmin SDK setup.

## Candidate approaches
1. Ubuntu 22.04 / Jammy container with Xvfb and SDK mounted in.
2. Distrobox / podman / docker-style userspace if available.
3. chroot/proot fallback if container runtime is unavailable.

## Immediate steps
1. Check which container tools exist on host.
2. If available, launch a Jammy container.
3. Install minimal simulator deps inside it.
4. Bind-mount SDK + project.
5. Start Xvfb, simulator, monkeydo.
6. Capture screenshot and assess layout.
