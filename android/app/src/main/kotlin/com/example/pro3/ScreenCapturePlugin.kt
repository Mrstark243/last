package com.example.pro3

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream

class ScreenCapturePlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var isCapturing = false
    private val handler = Handler(Looper.getMainLooper())
    private var screenWidth = 0
    private var screenHeight = 0
    private var screenDensity = 0
    private var pendingResult: Result? = null
    private val captureRunnable = object : Runnable {
        override fun run() {
            if (isCapturing) {
                captureScreen()
                handler.postDelayed(this, 100) // 10 FPS
            }
        }
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.pro3/screen_capture")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "requestMediaProjection" -> {
                requestMediaProjection(result)
            }
            "startScreenCapture" -> {
                startScreenCapture(result)
            }
            "stopScreenCapture" -> {
                stopScreenCapture(result)
            }
            "captureScreen" -> {
                captureScreen()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun requestMediaProjection(result: Result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        // Start the foreground service first
        val serviceIntent = Intent(activity, ScreenCaptureService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity?.startForegroundService(serviceIntent)
        } else {
            activity?.startService(serviceIntent)
        }

        val mediaProjectionManager = activity?.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        activity?.startActivityForResult(
            mediaProjectionManager.createScreenCaptureIntent(),
            REQUEST_MEDIA_PROJECTION
        )
        pendingResult = result
    }
    
    // Handle the activity result
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            val result = pendingResult ?: return
            pendingResult = null
            
            if (resultCode == Activity.RESULT_OK && data != null) {
                val projectionManager = activity?.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
                if (projectionManager != null) {
                    mediaProjection = projectionManager.getMediaProjection(resultCode, data)
                    result.success(true)
                } else {
                    result.error("PROJECTION_ERROR", "Failed to get MediaProjectionManager", null)
                }
            } else {
                result.success(false)
            }
        }
    }
    
    private fun startScreenCapture(result: Result) {
        if (mediaProjection == null) {
            result.error("NO_PROJECTION", "Media projection not available", null)
            return
        }
        
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(metrics)
        
        screenWidth = metrics.widthPixels
        screenHeight = metrics.heightPixels
        screenDensity = metrics.densityDpi
        
        imageReader = ImageReader.newInstance(screenWidth, screenHeight, android.graphics.PixelFormat.RGBA_8888, 2)
        
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            screenWidth,
            screenHeight,
            screenDensity,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            handler
        )
        
        // Start the WebSocket server service
        val serverIntent = Intent(context, WebSocketServerService::class.java)
        context.startService(serverIntent)
        
        isCapturing = true
        handler.post(captureRunnable)
        result.success(true)
    }
    
    private fun stopScreenCapture(result: Result) {
        isCapturing = false
        handler.removeCallbacks(captureRunnable)
        
        virtualDisplay?.release()
        virtualDisplay = null
        
        imageReader?.close()
        imageReader = null
        
        // Stop the WebSocket server service
        val serverIntent = Intent(context, WebSocketServerService::class.java)
        context.stopService(serverIntent)
        
        result.success(true)
    }
    
    private fun captureScreen() {
        val image = imageReader?.acquireLatestImage() ?: return
        
        try {
            val planes = image.planes
            val buffer = planes[0].buffer
            val pixelStride = planes[0].pixelStride
            val rowStride = planes[0].rowStride
            val rowPadding = rowStride - pixelStride * screenWidth
            
            val bitmap = android.graphics.Bitmap.createBitmap(
                screenWidth + rowPadding / pixelStride,
                screenHeight,
                android.graphics.Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)
            
            val croppedBitmap = android.graphics.Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)
            bitmap.recycle()
            
            val file = File(context.cacheDir, "screen_capture.png")
            val outputStream = FileOutputStream(file)
            croppedBitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, outputStream)
            outputStream.flush()
            outputStream.close()
            croppedBitmap.recycle()
            
            channel.invokeMethod("onScreenCaptured", file.absolutePath)
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            image.close()
        }
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener { requestCode, resultCode, data ->
            if (requestCode == REQUEST_MEDIA_PROJECTION) {
                onActivityResult(requestCode, resultCode, data)
                true
            } else {
                false
            }
        }
    }
    
    override fun onDetachedFromActivity() {
        activity = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    
    companion object {
        private const val REQUEST_CODE = 100
        private const val REQUEST_MEDIA_PROJECTION = 101
    }
}
