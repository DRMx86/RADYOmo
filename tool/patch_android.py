#!/usr/bin/env python3
"""Patches generated Android files for just_audio_background and Android TV."""
import pathlib
import re

def patch_manifest():
    manifest_path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
    if not manifest_path.exists():
        print("Manifest not found. Make sure to run 'flutter create' first.")
        return

    content = manifest_path.read_text()

    # 1. Change the app name
    content = re.sub(r'android:label="[^"]*"', 'android:label="RADYOmo"', content)

    # 2. Add all required permissions safely BEFORE the <application> tag
    permissions = """
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_LOCAL_NETWORK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    
    <!-- Android TV Support -->
    <uses-feature android:name="android.software.leanback" android:required="false" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />
"""
    if 'android.permission.WAKE_LOCK' not in content:
        content = content.replace('<application', permissions + '\n    <application', 1)

    # 3. Safely add usesCleartextTraffic and Banner attribute to the <application> tag
    if 'android:usesCleartextTraffic="true"' not in content:
        content = re.sub(
            r'(<application\s+)',
            r'\1android:usesCleartextTraffic="true"\n        android:banner="@mipmap/ic_launcher"\n        ',
            content,
            count=1
        )

    # 4. Add LEANBACK_LAUNCHER for Android TV Icon
    if 'android.intent.category.LEANBACK_LAUNCHER' not in content:
        content = content.replace(
            '<category android:name="android.intent.category.LAUNCHER"/>',
            '<category android:name="android.intent.category.LAUNCHER"/>\n            <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>'
        )

    # 5. Add AudioService and Receiver before the closing </application> tag
    audio_service_xml = """
    <service
        android:name="com.ryanheise.audioservice.AudioService"
        android:foregroundServiceType="mediaPlayback"
        android:exported="true">
        <intent-filter>
            <action android:name="android.media.browse.MediaBrowserService" />
        </intent-filter>
    </service>
    <receiver
        android:name="com.ryanheise.audioservice.MediaButtonReceiver"
        android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.MEDIA_BUTTON" />
        </intent-filter>
    </receiver>
"""
    if 'com.ryanheise.audioservice.AudioService' not in content:
        content = content.replace('</application>', audio_service_xml + '\n    </application>')

    manifest_path.write_text(content)
    print("Successfully patched AndroidManifest.xml for TV & Audio")

def patch_main_activity():
    main_activity_paths = list(pathlib.Path("android").rglob("MainActivity.kt"))
    if not main_activity_paths:
        return

    for activity_path in main_activity_paths:
        content = activity_path.read_text()
        
        import_statement = "import com.ryanheise.audioservice.AudioServiceActivity"
        if import_statement not in content:
            content = re.sub(r'(package\s+[^\n]+\n)', r'\1\n' + import_statement + '\n', content, count=1)

        content = re.sub(
            r'class\s+MainActivity\s*:\s*FlutterActivity\s*\(\s*\)', 
            'class MainActivity: AudioServiceActivity()', 
            content
        )
        content = re.sub(
            r'class\s+MainActivity\s*:\s*FlutterFragmentActivity\s*\(\s*\)', 
            'class MainActivity: AudioServiceFragmentActivity()', 
            content
        )

        activity_path.write_text(content)
        print(f"Successfully patched {activity_path}")

if __name__ == "__main__":
    patch_manifest()
    patch_main_activity()
