# Eject All

One-click macOS menu bar app: click the eject icon and every external volume is unmounted and its disk ejected (internal disks skipped). Right-click the icon for the menu. Drives that another process holds open (e.g. a sandbox VM with read-only handles) are force-unmounted; anything that still fails is listed in an alert.

Build and install (needs only Xcode Command Line Tools): `./build.sh`
