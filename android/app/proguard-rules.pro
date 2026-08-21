# The JavaScript bridge is reached by name from the web layer, so it must survive
# shrinking even though nothing in Java calls it.
-keepclassmembers class com.elyasomar.battleofagents.LanBridge {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.elyasomar.battleofagents.LanBridge { *; }
