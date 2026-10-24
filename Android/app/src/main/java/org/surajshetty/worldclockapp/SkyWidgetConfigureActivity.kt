package org.surajshetty.worldclockapp

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The widget's city picker: shown when the widget is added, and again from the
 * launcher's "edit widget" action (Android 12+, see `reconfigurable` in
 * sky_widget_info.xml). Offers only the cities saved in the app.
 */
class SkyWidgetConfigureActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        // Backing out without picking must not leave a half-added widget behind.
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()

        val cities = ClockRepository(this).loadEntries().sortedBy { it.sortOrder }
        setContent {
            Column(Modifier.fillMaxSize().background(Theme.ground).safeDrawingPadding().padding(16.dp)) {
                Text("Pick a city", color = Theme.textBright, fontSize = 24.sp, fontWeight = FontWeight.Medium)
                if (cities.isEmpty()) {
                    Text(
                        "Add cities in World Clock first — the widget shows your local time until then.",
                        color = Theme.text, modifier = Modifier.padding(top = 12.dp)
                    )
                }
                LazyColumn(Modifier.padding(top = 12.dp)) {
                    items(cities, key = { it.id }) { city ->
                        val country = CountryLookup.lookup(city.timeZoneId)
                        Column(
                            Modifier.fillMaxWidth().clickable { pick(widgetId, city) }.padding(vertical = 14.dp)
                        ) {
                            Text("${country?.flag?.plus("  ") ?: ""}${city.label}", color = Theme.textBright, fontSize = 18.sp)
                            country?.let { Text(it.name, color = Theme.text.copy(alpha = 0.6f), fontSize = 13.sp) }
                        }
                    }
                }
            }
        }
    }

    private fun pick(widgetId: Int, city: ClockEntry) {
        SkyWidget.setCity(this, widgetId, city.id)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }
}
