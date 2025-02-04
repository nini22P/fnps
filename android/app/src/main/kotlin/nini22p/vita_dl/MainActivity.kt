package nini22p.vita_dl

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(){
    private val CHANNEL = "mychannel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
           when (call.method) {
                "getNativeLibraryDir" -> {
                    result.success(applicationContext.applicationInfo.nativeLibraryDir)
                }
               else -> {
                   result.notImplemented()
               }
           }
        }
    }
}