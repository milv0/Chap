# App icon

The app icon is the pixel seal from `Sources/ChapCore/ChapMascot.swift`, so the
icon and the seal on the notch strip are the same drawing. Ink colors come from
the mascot table in `DESIGN.md`.

`app-icon-1024.png` is the master. To regenerate it and bake the icon set:

```bash
xcrun swift assets/icons/make-app-icon.swift "$PWD/assets/icons/app-icon-1024.png"

rm -rf /tmp/AppIcon.iconset && mkdir -p /tmp/AppIcon.iconset
for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
            "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" \
            "512 icon_256x256@2x" "512 icon_512x512" "1024 icon_512x512@2x"; do
  set -- $spec
  sips -z "$1" "$1" assets/icons/app-icon-1024.png --out "/tmp/AppIcon.iconset/$2.png"
done
iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns

# Website favicon and header icon use the same art.
sips -z 256 256 assets/icons/app-icon-1024.png --out docs/assets/chap-icon-rounded.png
```
