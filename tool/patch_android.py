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

    # 1. Add ALL required permissions (including network ones)
    permissions_to_add = [
        '<uses-permission android:name="android.permission.WAKE_LOCK"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>',
        '<uses-permission android:name="android.permission.INTERNET"/>', # For network audio streaming
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>', # Recommended
        '<uses-permission android:name="android.permission.ACCESS_LOCAL_NETWORK"/>' # Required for the local media server
    ]
    
    for perm in permissions_to_add:
        if perm not in content:
            content = content.replace('<application', perm + '\n    <application', 1)

    # 2. Add the AudioService and MediaButtonReceiver
    audio_service_xml = """
    <!-- AudioService for background playback -->
    <service
        android:name="com.ryanheise.audioservice.AudioService"
        android:foregroundServiceType="mediaPlayback"
        android:exported="true">
        <intent-filter>
            <action android:name="android.media.browse.MediaBrowserService" />
        </intent-filter>
    </service>

    <!-- MediaButtonReceiver for headset controls -->
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
    # Find the MainActivity.kt file (path may vary based on package name)
    main_activity_paths = list(pathlib.Path("android").rglob("MainActivity.kt"))
    if not main_activity_paths:
        main_activity_paths = list(pathlib.Path("android").rglob("MainActivity.java"))

    if not main_activity_paths:
        print("MainActivity.kt/java not found. Cannot patch activity.")
        return

    for activity_path in main_activity_paths:
        content = activity_path.read_text()
        original_content = content

        # 1. Add the import for AudioServiceActivity
        import_statement = "import com.ryanheise.audioservice.AudioServiceActivity"
        if import_statement not in content:
            content = re.sub(r'(package\s+[^\n]+\n)', r'\1\n' + import_statement + '\n', content, count=1)

        # 2. Change the superclass from FlutterActivity to AudioServiceActivity
        content = re.sub(
            r'class\s+MainActivity\s*:\s*FlutterActivity\s*\(\s*\)',
            'class MainActivity: AudioServiceActivity()',
            content
        )

        if content != original_content:
            activity_path.write_text(content)
            print(f"Successfully patched {activity_path}")
        else:
            print(f"No changes needed for {activity_path}")

if __name__ == "__main__":
    patch_manifest()
    patch_main_activity()
