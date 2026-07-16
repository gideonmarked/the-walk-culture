# Android Gradle tweaks — doc §3.4(c)(d)

After `flutter create`, apply these to the generated Android project.

## `android/app/build.gradle` (or `build.gradle.kts`)
Health Connect's floor is Android 8.0, so:

```groovy
android {
    compileSdk = 34            // or current
    defaultConfig {
        applicationId = "com.perfeos.step_quest"
        minSdk = 26            // Health Connect requires >= 26
        targetSdk = 34         // or current
    }
}
```

> If Flutter templated `minSdkVersion flutter.minSdkVersion`, override it to `26`.

## `android/gradle.properties`
```properties
org.gradle.jvmargs=-Xmx1536M
android.enableJetifier=true
android.useAndroidX=true
```

## Reminder
`MainActivity` must extend `FlutterFragmentActivity` — use
`platform_config/MainActivity.kt` (the setup script copies it into place).
