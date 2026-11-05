#!/usr/bin/env python3
"""Patches the generated AndroidManifest.xml for just_audio_background."""
import pathlib

def patch_manifest():
    manifest_path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
    if not manifest_path.exists():
        print("Manifest not found. Make sure to run 'flutter create' first.")
        return

    content = manifest_path.read_text()

    # 1. Add required permissions
    permissions_to_add = [
        '<uses-permission android:name="android.permission.WAKE_LOCK"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>'
    ]
    
    for perm in permissions_to_add:
        if perm not in content:
            # Insert before the <application> tag
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
        # Insert before the closing </application> tag
        content = content.replace('</application>', audio_service_xml + '\n</application>')

    # 3. Change the MainActivity to use AudioServiceActivity
    # The default activity is usually com.example.ph_radio.MainActivity
    # We need to replace it with com.ryanheise.audioservice.AudioServiceActivity
    if 'com.ryanheise.audioservice.AudioServiceActivity' not in content:
        # This regex finds the <activity> block that contains the MAIN/LAUNCHER intent filter
        # and replaces its android:name attribute.
        import re
        pattern = r'(<activity\s+[^>]*?android:name=")[^"]*("(?:(?!</activity>).)*?<intent-filter>\s*<action android:name="android.intent.action.MAIN" />)'
        
        def replacer(match):
            return match.group(1) + 'com.ryanheise.audioservice.AudioServiceActivity' + match.group(2)

        content = re.sub(pattern, replacer, content, flags=re.DOTALL)

    manifest_path.write_text(content)
    print("Successfully patched AndroidManifest.xml")

if __name__ == "__main__":
    patch_manifest()
