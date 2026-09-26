package com.velix.local.velix_local

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.velix.local/platform"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        acquireMulticastLock()
    }

    override fun onResume() {
        super.onResume()
        acquireMulticastLock()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDownloadsFolder" -> {
                    val opened = openDownloadsUI()
                    result.success(opened)
                }
                "scanFile" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        try {
                            MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(filePath),
                                null
                            ) { scannedPath, uri ->
                                // Notificação de indexação
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "checkStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else {
                        result.success(true)
                    }
                }
                "requestStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openDownloadsUI(): Boolean {
        // 1. Tentar abrir tela de Downloads via DownloadManager
        try {
            val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            return true
        } catch (_: Exception) {}

        // 2. Tentar abrir DocumentsUI na pasta Download
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                val uri = Uri.parse("content://com.android.externalstorage.documents/document/primary%3ADownload")
                setDataAndType(uri, "vnd.android.document/directory")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            return true
        } catch (_: Exception) {}

        // 3. Tentar abrir o aplicativo Files do Google / Fabricantes
        val fileManagerPackages = listOf(
            "com.google.android.apps.nbu.files",
            "com.google.android.documentsui",
            "com.sec.android.app.myfiles",
            "com.mi.android.globalFileexplorer",
            "com.motorola.filemanager"
        )
        for (pkg in fileManagerPackages) {
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                if (launchIntent != null) {
                    launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(launchIntent)
                    return true
                }
            } catch (_: Exception) {}
        }
        return false
    }

    private fun acquireMulticastLock() {
        try {
            if (multicastLock == null || !multicastLock!!.isHeld) {
                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                multicastLock = wifi.createMulticastLock("velix_multicast_lock")
                multicastLock?.setReferenceCounted(true)
                multicastLock?.acquire()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (multicastLock != null && multicastLock!!.isHeld) {
                multicastLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

