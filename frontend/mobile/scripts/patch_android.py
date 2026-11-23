"""Patch the generated Android project (Flutter 3.24, Groovy gradle)."""
import pathlib, re, sys

manifest = pathlib.Path('android/app/src/main/AndroidManifest.xml')
gradle = pathlib.Path('android/app/build.gradle')
if not manifest.exists() or not gradle.exists():
    sys.exit('Run flutter create first (android/ missing or not Groovy gradle)')

m = manifest.read_text()
if 'POST_NOTIFICATIONS' not in m:
    perms = (
        '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
        '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
    )
    m = m.replace('<application', perms + '    <application', 1)
    receivers = (
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>\n'
        '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
        '            </intent-filter>\n'
        '        </receiver>\n'
    )
    m = m.replace('</application>', receivers + '    </application>', 1)
    m = re.sub(r'android:label="[^"]*"', 'android:label="MyDay"', m, count=1)
    manifest.write_text(m)

g = gradle.read_text()
if 'coreLibraryDesugaringEnabled' not in g:
    g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', g, count=1)
    g = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', g)
    g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n"
    gradle.write_text(g)
g = gradle.read_text()
if 'minifyEnabled false' not in g:
    g = re.sub(r'(buildTypes\s*\{\s*release\s*\{)', r'\1\n            minifyEnabled false\n            shrinkResources false', g, count=1)
    gradle.write_text(g)
print('android project patched')
