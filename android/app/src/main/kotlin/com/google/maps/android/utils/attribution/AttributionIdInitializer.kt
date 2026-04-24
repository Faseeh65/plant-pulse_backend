package com.google.maps.android.utils.attribution

import android.content.Context
import androidx.startup.Initializer

class AttributionIdInitializer : Initializer<Unit> {
    override fun create(context: Context) {}
    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
