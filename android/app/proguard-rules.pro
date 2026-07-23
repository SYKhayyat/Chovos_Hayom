# R8 is on for release builds. Flutter's own rules cover the engine; these cover
# the plugins that reach native code reflectively and would otherwise be
# stripped — the failure mode is a release-only crash the debug build never
# shows, which is exactly the kind of bug that reaches users.

# drift / sqlite3_flutter_libs: the native sqlite3 bindings are resolved by name.
-keep class com.tekartik.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# shared_preferences and file_picker both use platform channels + reflection.
-keep class androidx.lifecycle.DefaultLifecycleObserver

# Keep annotations R8 would otherwise drop, so the above keeps still apply.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
