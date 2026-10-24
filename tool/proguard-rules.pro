# Copied to android/app/proguard-rules.pro by tool/configure_android.py.
#
# Google Mobile Ads starts WorkManager, whose Room database is created by
# reflection from its class name ("WorkDatabase" + "_Impl"). If R8 renames
# or removes these classes, the app crashes on launch with
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
