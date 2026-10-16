#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <prepared-runtime-directory> <bundle-id> <iPhoneSimulator|iPhoneOS> <new-app-directory>" >&2
    exit 2
fi
prepared=$1
bundle_id=$2
platform=$3
app=$4
case $bundle_id in
    ''|*[!A-Za-z0-9.-]*) echo 'Invalid bundle identifier.' >&2; exit 2 ;;
esac
case $platform in
    iPhoneSimulator|iPhoneOS) ;;
    *) echo 'Choose iPhoneSimulator or iPhoneOS.' >&2; exit 2 ;;
esac
test -f "$prepared/nxResourceRuntimeTests"
test -f "$prepared/runtimetables.res"
if [[ $(od -An -tx1 -N4 "$prepared/nxResourceRuntimeTests" | tr -d ' \n') != cffaedfe ]] ||
   [[ $(od -An -tx1 -j12 -N4 "$prepared/nxResourceRuntimeTests" | tr -d ' \n') != 02000000 ]]; then
    echo 'Expected a linked 64-bit Mach-O runtime test executable.' >&2
    exit 2
fi
if [[ -e $app ]]; then echo 'Choose a new app directory.' >&2; exit 2; fi
mkdir -p "$app"
cp "$prepared/nxResourceRuntimeTests" "$app/ResourceCheck"
chmod +x "$app/ResourceCheck"
cp "$prepared/runtimetables.res" "$app/"
cat >"$app/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleExecutable</key><string>ResourceCheck</string>
<key>CFBundleName</key><string>ResourceCheck</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
<key>MinimumOSVersion</key><string>14.0</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
</dict></plist>
EOF
echo "Prepared unsigned app: $app"
echo 'Use the matching simulator or your existing development signing/profile workflow.'
