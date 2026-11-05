#!/usr/bin/env python3
"""Patches generated Android files for just_audio_background."""
import pathlib
import re

def patch_manifest():
    manifest_path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
    if not manifest_path.exists():
        print("Manifest not found. Make sure to run 'flutter create' first.")
        return

    content = manifest_path.read_text()

    # 1. Add all required permissions
    permissions = [
        '<uses-permission android:name="android.permission.WAKE_LOCK"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>',
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
        '<uses-permission android:name="android.permission.ACCESS_LOCAL_NETWORK"/>'
    ]
    
    for perm in permissions:
        if perm not in content:
            # Add permissions right after the <manifest> tag
            content = content.replace('<manifest', '<manifest\n    ' + perm, 1)

    # 2. Enable Cleartext Traffic (Crucial for HTTP radio streams)
    if 'android:usesCleartextTraffic="true"' not in content:
        content = content.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)

    # 3. Add AudioService and Receiver
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
        content = content.replace('</application>', audio_service_xml + '\n</application>')

    manifest_path.write_text(content)
    print("Successfully patched AndroidManifest.xml")

def patch_main_activity():
    # Find MainActivity.kt
    main_activity_paths = list(pathlib.Path("android").rglob("MainActivity.kt"))
    if not main_activity_paths:
        return

    for activity_path in main_activity_paths:
        content = activity_path.read_text()
        
        # Add import for AudioServiceActivity
        import_statement = "import com.ryanheise.audioservice.AudioServiceActivity"
        if import_statement not in content:
            content = re.sub(r'(package\s+[^\n]+\n)', r'\1\n' + import_statement + '\n', content, count=1)

        # Change FlutterActivity to AudioServiceActivity
        content = content.replace('FlutterActivity()', 'AudioServiceActivity()')
        content = content.replace('FlutterFragmentActivity()', 'AudioServiceFragmentActivity()')

        activity_path.write_text(content)
        print(f"Successfully patched {activity_path}")

if __name__ == "__main__":
    patch_manifest()
    patch_main_activity()
