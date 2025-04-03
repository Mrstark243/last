package com.example.pro3

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.ByteArrayOutputStream
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayInputStream
import java.nio.ByteBuffer

class WebSocketServerService : Service() {
    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    private val executorService: ExecutorService = Executors.newCachedThreadPool()
    private val TAG = "WebSocketServerService"
    private var clients = mutableListOf<Socket>()
    
    override fun onCreate() {
        super.onCreate()
        startServer()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    private fun startServer() {
        executorService.execute {
            try {
                serverSocket = ServerSocket(5000)
                isRunning = true
                Log.d(TAG, "Server started on port 5000")
                Log.d(TAG, "Local IP: ${getLocalIpAddress()}")
                
                while (isRunning) {
                    try {
                        val clientSocket = serverSocket?.accept()
                        clientSocket?.let { 
                            synchronized(clients) {
                                clients.add(it)
                            }
                            handleClient(it)
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "Error accepting client connection", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error starting server", e)
            }
        }
    }
    
    private fun handleClient(clientSocket: Socket) {
        executorService.execute {
            try {
                val outputStream = DataOutputStream(clientSocket.getOutputStream())
                
                while (isRunning && !clientSocket.isClosed) {
                    val screenCaptureFile = File(applicationContext.cacheDir, "screen_capture.png")
                    if (screenCaptureFile.exists()) {
                        try {
                            // Read the image file
                            val imageBytes = screenCaptureFile.readBytes()
                            
                            // Compress the image
                            val compressedBytes = compressImage(imageBytes)
                            
                            // Create a buffer for the size (4 bytes) and image data
                            val buffer = ByteBuffer.allocate(4 + compressedBytes.size)
                            
                            // Write the size (4 bytes)
                            buffer.putInt(compressedBytes.size)
                            
                            // Write the image data
                            buffer.put(compressedBytes)
                            
                            // Send the complete buffer
                            outputStream.write(buffer.array())
                            outputStream.flush()
                            
                            // Small delay to control frame rate
                            Thread.sleep(100) // 10 FPS
                        } catch (e: Exception) {
                            Log.e(TAG, "Error processing image", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling client", e)
            } finally {
                try {
                    synchronized(clients) {
                        clients.remove(clientSocket)
                    }
                    clientSocket.close()
                } catch (e: Exception) {
                    Log.e(TAG, "Error closing client socket", e)
                }
            }
        }
    }
    
    private fun compressImage(imageBytes: ByteArray): ByteArray {
        try {
            // Decode the image
            val options = BitmapFactory.Options().apply {
                inSampleSize = 2 // Reduce image size by half
            }
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, options)
            
            if (bitmap == null) {
                Log.e(TAG, "Failed to decode image")
                return imageBytes
            }
            
            // Compress the image
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
            
            return outputStream.toByteArray()
        } catch (e: Exception) {
            Log.e(TAG, "Error compressing image", e)
            return imageBytes
        }
    }
    
    private fun getLocalIpAddress(): String {
        NetworkInterface.getNetworkInterfaces().toList()
            .flatMap { it.inetAddresses.toList() }
            .find { !it.isLoopbackAddress && it.hostAddress.indexOf(':') < 0 }
            ?.let { return it.hostAddress }
        return "127.0.0.1"
    }
    
    override fun onDestroy() {
        isRunning = false
        synchronized(clients) {
            clients.forEach { client ->
                try {
                    client.close()
                } catch (e: Exception) {
                    Log.e(TAG, "Error closing client socket", e)
                }
            }
            clients.clear()
        }
        try {
            serverSocket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing server socket", e)
        }
        executorService.shutdown()
        super.onDestroy()
    }
} 