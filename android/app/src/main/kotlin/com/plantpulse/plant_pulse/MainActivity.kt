package com.plantpulse.plant_pulse

import android.os.Bundle
import com.google.android.gms.maps.MapsInitializer
import com.google.android.gms.maps.MapsInitializer.Renderer
import com.google.android.gms.maps.OnMapsSdkInitializedCallback
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity(), OnMapsSdkInitializedCallback {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MapsInitializer.initialize(applicationContext, Renderer.LATEST, this)
    }

    override fun onMapsSdkInitialized(renderer: Renderer) {
        // Callback confirming the renderer version
    }
}
