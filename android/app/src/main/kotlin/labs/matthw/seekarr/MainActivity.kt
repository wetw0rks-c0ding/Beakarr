package labs.matthw.seekarr

import io.flutter.embedding.android.FlutterActivity
import android.app.Activity
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle intent with URI (cold start / deep link launch)
        val uri = intent?.data
        
        // The app_links plugin will handle the deep link callback detection
        // We pass any initial URI to Flutter for processing
        if (uri != null && uri.scheme == "seekarr") {
            // Cold-started with a deep link - let Flutter handle it
        }
    }
}
