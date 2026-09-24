package com.example.verygoodcore.food_ninja

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.util.Base64
import android.util.Log
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * Android SMS Retriever for the sign-up code (lib/src/services/sms_code_listener.dart).
 * Google Play services hands over one SMS that ends with this app's 11-character
 * hash, with no SMS permission and no tap. It listens for 5 minutes per start.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "food_ninja/sms").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startRetriever(result)
                    "stop" -> {
                        stopRetriever()
                        result.success(null)
                    }
                    "appSignature" -> result.success(appSignature())
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        stopRetriever()
        super.onDestroy()
    }

    private fun startRetriever(result: MethodChannel.Result) {
        stopRetriever()
        val smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                val extras = intent.extras ?: return
                @Suppress("DEPRECATION")
                val status = extras.get(SmsRetriever.EXTRA_STATUS) as? Status ?: return
                when (status.statusCode) {
                    CommonStatusCodes.SUCCESS ->
                        channel?.invokeMethod("onSms", extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE))
                    CommonStatusCodes.TIMEOUT -> channel?.invokeMethod("onTimeout", null)
                }
                stopRetriever()
            }
        }
        val filter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        // Only Play services (holding SEND_PERMISSION) may deliver to this receiver.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, SmsRetriever.SEND_PERMISSION, null, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(smsReceiver, filter, SmsRetriever.SEND_PERMISSION, null)
        }
        receiver = smsReceiver

        SmsRetriever.getClient(this).startSmsRetriever()
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { e ->
                Log.w("SmsRetriever", "start failed", e)
                stopRetriever()
                result.success(false)
            }
    }

    private fun stopRetriever() {
        receiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: IllegalArgumentException) {
                Log.w("SmsRetriever", "receiver already unregistered", e)
            }
        }
        receiver = null
    }

    /** The hash the server must append to the SMS; differs for debug and release signing. */
    private fun appSignature(): String? {
        return try {
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                    .signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
            }
            val signature = signatures?.firstOrNull() ?: return null
            val digest = MessageDigest.getInstance("SHA-256")
                .digest("$packageName ${signature.toCharsString()}".toByteArray(Charsets.UTF_8))
            Base64.encodeToString(digest.copyOfRange(0, 9), Base64.NO_PADDING or Base64.NO_WRAP)
                .substring(0, 11)
        } catch (e: Exception) {
            Log.w("SmsRetriever", "app signature failed", e)
            null
        }
    }
}
