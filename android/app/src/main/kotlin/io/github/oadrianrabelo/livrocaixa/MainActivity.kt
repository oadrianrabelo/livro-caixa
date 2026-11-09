package io.github.oadrianrabelo.livrocaixa

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Canal "livro_caixa/updates": a parte do atualizador que só o Android sabe fazer.
// O lado Dart está em lib/updates/updater.dart.
// FlutterFragmentActivity: exigido pela digital (local_auth).
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "livro_caixa/updates").setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                )
                "openInstallSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                    )
                    result.success(null)
                }
                "installApk" -> {
                    val file = File(call.argument<String>("path")!!)
                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                    startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
