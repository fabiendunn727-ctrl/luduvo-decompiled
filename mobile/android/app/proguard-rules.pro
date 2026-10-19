# Luduvo ProGuard Rules

# Keep native method names
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep JNI bridge class
-keep class com.luduvo.client.LuduvoEngine {
    native <methods>;
    public *;
}

# Keep main activity and application
-keep class com.luduvo.client.MainActivity { *; }
-keep class com.luduvo.client.LuduvoApplication { *; }

# Keep SurfaceView and callbacks
-keep class com.luduvo.client.LuduvoSurfaceView { *; }

# Keep kotlin coroutines
-keep class kotlinx.coroutines.** { *; }

# Don't obfuscate serialization
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep annotations
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# SDL3 native calls
-keep class org.libsdl.** { *; }

# Luau VM
-keep class luau.** { *; }

# flecs ECS
-keep class flecs.** { *; }