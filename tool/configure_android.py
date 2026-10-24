"""Patches the android/ folder that `flutter create` generates in the cloud.

- Adds the INTERNET permission and sets the app label.
- Adds a monochrome notification icon for the daily Hukamnama notification.
- Adds the AdMob application ID (ADMOB_APP_ID overrides the one below).
- Adds R8 keep rules (tool/proguard-rules.pro) so release builds don't crash.
- Signs release builds with the Play upload key when android/key.properties
  exists; otherwise release builds keep using the debug key.
"""

import os
import re
import shutil
import sys
from pathlib import Path

# Google's test app ID until this app gets its own AdMob app ID.
ADMOB_APP_ID = "ca-app-pub-3940256099942544~3347511713"
APP_LABEL = "Daily Hukamnama"

manifest_path = Path("android/app/src/main/AndroidManifest.xml")
gradle_path = Path("android/app/build.gradle.kts")
proguard_source = Path(__file__).with_name("proguard-rules.pro")
# The Flutter Gradle plugin applies this file to release builds automatically.
proguard_target = Path("android/app/proguard-rules.pro")


def patch_manifest() -> None:
    text = manifest_path.read_text()

    if "android.permission.INTERNET" not in text:
        text = text.replace(
            "<application",
            '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
            1,
        )

    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', text, count=1)

    app_id = os.environ.get("ADMOB_APP_ID", "").strip() or ADMOB_APP_ID
    if not re.fullmatch(r"ca-app-pub-\d{16}~\d{10}", app_id):
        sys.exit(f"Invalid AdMob app ID: {app_id}")
    if "com.google.android.gms.ads.APPLICATION_ID" not in text:
        text = text.replace(
            "</application>",
            "    <meta-data\n"
            '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
            f'            android:value="{app_id}"/>\n'
            "    </application>",
            1,
        )

    if "default_notification_icon" not in text:
        text = text.replace(
            "</application>",
            "    <meta-data\n"
            '            android:name="com.google.firebase.messaging.default_notification_icon"\n'
            '            android:resource="@drawable/ic_notification"/>\n'
            "        <meta-data\n"
            '            android:name="com.google.firebase.messaging.default_notification_color"\n'
            '            android:resource="@color/notification_gold"/>\n'
            "    </application>",
            1,
        )

    manifest_path.write_text(text)


def add_notification_resources() -> None:
    """A small white dawn-sun icon (Android tints it) and the gold accent."""
    res = Path("android/app/src/main/res")
    (res / "drawable").mkdir(parents=True, exist_ok=True)
    (res / "drawable" / "ic_notification.xml").write_text(
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="24dp" android:height="24dp"\n'
        '    android:viewportWidth="24" android:viewportHeight="24">\n'
        '  <path android:fillColor="#FFFFFFFF" android:pathData="M6,14a6,6 0,0 1,12 0z"/>\n'
        '  <path android:fillColor="#FFFFFFFF" android:pathData="M3,15h18v1.5h-18z"/>\n'
        '  <path android:fillColor="#FFFFFFFF" android:pathData="M7,18h10v1.2h-10z"/>\n'
        '  <path android:fillColor="#FFFFFFFF" android:pathData="M9.5,20.6h5v1.2h-5z"/>\n'
        "</vector>\n"
    )
    (res / "values").mkdir(parents=True, exist_ok=True)
    (res / "values" / "notification_colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n    <color name="notification_gold">#C9A24A</color>\n</resources>\n'
    )


def patch_gradle() -> None:
    text = gradle_path.read_text()
    if "keystoreProperties" in text:
        return

    debug_signing = 'signingConfig = signingConfigs.getByName("debug")'
    if debug_signing not in text or "\nandroid {" not in text:
        sys.exit("Unexpected build.gradle.kts layout; signing not configured.")

    header = (
        "import java.io.FileInputStream\n"
        "import java.util.Properties\n\n"
    )
    loader = (
        "val keystoreProperties = Properties()\n"
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
        "}\n\n"
        "android {\n"
        "    signingConfigs {\n"
        '        create("release") {\n'
        "            if (keystorePropertiesFile.exists()) {\n"
        '                keyAlias = keystoreProperties["keyAlias"] as String\n'
        '                keyPassword = keystoreProperties["keyPassword"] as String\n'
        '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '                storePassword = keystoreProperties["storePassword"] as String\n'
        "            }\n"
        "        }\n"
        "    }\n"
    )
    text = header + text.replace("\nandroid {\n", "\n" + loader, 1)
    text = text.replace(
        debug_signing,
        "signingConfig = if (keystorePropertiesFile.exists()) "
        'signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
        1,
    )
    gradle_path.write_text(text)


patch_manifest()
patch_gradle()
add_notification_resources()
shutil.copyfile(proguard_source, proguard_target)
print(manifest_path.read_text())
