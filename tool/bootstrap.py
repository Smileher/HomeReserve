"""Generate Flutter's pinned native runners and apply minimal platform branding."""
from pathlib import Path
import os
import re
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
subprocess.run(["flutter", "create", "--no-pub", "--platforms=android,windows,macos", "--org=dev.smileher", "--project-name=home_reserve", "."], check=True)

manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8").replace('android:label="home_reserve"', 'android:label="家有余" android:allowBackup="false"')
manifest.write_text(text, encoding="utf-8")
gradle = ROOT / "android/app/build.gradle.kts"
text = gradle.read_text(encoding="utf-8").replace("minSdk = flutter.minSdkVersion", "minSdk = 26")
if 'create("release")' not in text:
    text = text.replace("    buildTypes {", '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH") ?: "release.jks")
            storePassword = System.getenv("ANDROID_STORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "homereserve"
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
    buildTypes {''').replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
gradle.write_text(text, encoding="utf-8")

config = ROOT / "macos/Runner/Configs/AppInfo.xcconfig"
text = config.read_text(encoding="utf-8")
text = re.sub(r"PRODUCT_NAME = .*", "PRODUCT_NAME = HomeReserve", text)
text = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = .*", "PRODUCT_BUNDLE_IDENTIFIER = dev.smileher.homereserve", text)
text = re.sub(r"PRODUCT_COPYRIGHT = .*", "PRODUCT_COPYRIGHT = Copyright © 2026 he. MIT License.", text)
config.write_text(text, encoding="utf-8")
for filename in ["DebugProfile.entitlements", "Release.entitlements"]:
    target = ROOT / "macos/Runner" / filename
    text = target.read_text(encoding="utf-8")
    if "com.apple.security.files.user-selected.read-write" not in text:
        text = text.replace("</dict>", "<key>com.apple.security.files.user-selected.read-write</key><true/>\n</dict>")
    target.write_text(text, encoding="utf-8")
project = ROOT / "macos/Runner.xcodeproj/project.pbxproj"
project.write_text(re.sub(r"MACOSX_DEPLOYMENT_TARGET = [^;]+;", "MACOSX_DEPLOYMENT_TARGET = 13.0;", project.read_text(encoding="utf-8")), encoding="utf-8")
podfile = ROOT / "macos/Podfile"
if podfile.exists():
    podfile.write_text(re.sub(r"platform :osx, '[^']+'", "platform :osx, '13.0'", podfile.read_text(encoding="utf-8")), encoding="utf-8")

# Use freely redistributable Noto; instantiate a static font for PDF compatibility.
fonts = ROOT / "assets/fonts"
fonts.mkdir(parents=True, exist_ok=True)
font_path = fonts / "NotoSansSC-Regular.ttf"
if not font_path.exists():
    variable = fonts / "NotoSansSC-variable.ttf"
    urllib.request.urlretrieve("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf", variable)
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
    font = instantiateVariableFont(TTFont(variable), {"wght": 400}, inplace=True)
    font.save(font_path)
    variable.unlink()
    urllib.request.urlretrieve("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt", fonts / "OFL.txt")

from PIL import Image, ImageDraw
def icon(size):
    image = Image.new("RGBA", (1024, 1024), (31, 111, 91, 255))
    draw = ImageDraw.Draw(image)
    draw.line([(205, 470), (512, 220), (819, 470)], fill="#f1f7eb", width=56, joint="curve")
    draw.rounded_rectangle((285, 432, 740, 805), radius=72, fill="#f1f7eb")
    draw.ellipse((415, 480, 610, 675), fill="#a1c7a4")
    draw.line([(512, 748), (512, 563)], fill="#1f6f5b", width=26)
    draw.ellipse((505, 530, 645, 610), fill="#1f6f5b")
    return image.resize((size, size), Image.Resampling.LANCZOS)
for density, size in {"mdpi":48,"hdpi":72,"xhdpi":96,"xxhdpi":144,"xxxhdpi":192}.items():
    target=ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
    icon(size).save(target)
for size in [16,32,64,128,256,512,1024]:
    target=ROOT / f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png"
    icon(size).save(target)
icon(256).save(ROOT / "windows/runner/resources/app_icon.ico", sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
runner=ROOT / "windows/runner/main.cpp"
runner.write_text(runner.read_text(encoding="utf-8").replace('L"home_reserve"', 'L"HomeReserve"'), encoding="utf-8")
print("Native runners, signing configuration, icons and report font prepared.")
