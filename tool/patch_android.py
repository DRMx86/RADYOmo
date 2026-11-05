"""Patches the generated Android project for background audio playback."""
import re, pathlib

p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text()

perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
"""
if "FOREGROUND_SERVICE_MEDIA_PLAYBACK" not in s:
    s = s.replace("<application", perms + "    <application", 1)

# Use audio_service's activity so the media session attaches correctly
s = s.replace('android:name=".MainActivity"',
              'android:name="com.ryanheise.audioservice.AudioServiceActivity"')

s = re.sub(r'android:label="[^"]*"', 'android:label="PH Radio"', s, count=1)

svc = """
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
"""
if "com.ryanheise.audioservice.AudioService" not in s:
    s = s.replace("</application>", svc + "    </application>", 1)

if "xmlns:tools" not in s:
    s = s.replace("<manifest ", '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)

p.write_text(s)
print("Manifest patched")
