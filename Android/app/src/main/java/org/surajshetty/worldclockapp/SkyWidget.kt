package org.surajshetty.worldclockapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import java.time.LocalTime
import java.time.ZoneId
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Home-screen widget: one saved city's time over the "Nocturne" sky for that city's
 * hour. The city is picked per widget in [SkyWidgetConfigureActivity]; until one is
 * picked (or if it's later deleted from the app) it shows the device's own zone.
 *
 * Keeping it fresh is split in two, because the two halves change at very different rates:
 *  - The time and date are framework TextClocks, pinned to the city's zone, which the
 *    launcher ticks itself every minute (and follows the 12/24h setting) — no updates
 *    from us needed.
 *  - The sky is a bitmap we render, so it only changes when we push a new one. A
 *    non-wakeup RTC alarm re-renders it every [SKY_REFRESH_MINUTES]: it never wakes a
 *    sleeping device, it just fires as soon as the screen comes back on, which is the
 *    only time anyone can see the widget anyway. Each firing schedules the next.
 *    (`updatePeriodMillis` can't go below 30 minutes and wakes the device, so it's off.)
 *  - Clock/zone changes are caught by the manifest's TIME_SET/TIMEZONE_CHANGED filters,
 *    both of which are exempt from Android 8's implicit-broadcast limits.
 *  - Edits to the saved city list call [refresh] (from ClockRepository.saveEntries).
 */
class SkyWidget : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REFRESH, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> updateAll(context)
            else -> super.onReceive(context, intent)
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = updateAll(context)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) =
        update(context, manager, id) // resized: re-render at the new aspect ratio

    override fun onDeleted(context: Context, ids: IntArray) {
        prefs(context).edit().apply { ids.forEach { remove(cityKey(it)) } }.apply()
    }

    override fun onDisabled(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(refreshIntent(context))
    }

    private fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, SkyWidget::class.java))
        if (ids.isEmpty()) return
        ids.forEach { update(context, manager, it) }
        scheduleNextRefresh(context)
    }

    private fun update(context: Context, manager: AppWidgetManager, id: Int) {
        val cityId = prefs(context).getString(cityKey(id), null)
        val city = ClockRepository(context).loadEntries().firstOrNull { it.id == cityId }
        val zone = city?.let { runCatching { ZoneId.of(it.timeZoneId) }.getOrNull() } ?: ZoneId.systemDefault()
        val label = city?.label ?: TimeZoneCatalog.displayLabel(zone.id)
        val now = LocalTime.now(zone)
        val hour = now.hour + now.minute / 60.0

        val views = RemoteViews(context.packageName, R.layout.sky_widget)
        val (w, h) = bitmapSize(context, manager.getAppWidgetOptions(id))
        views.setImageViewBitmap(R.id.sky, renderSkyBitmap(hour, w, h))
        views.setTextViewText(R.id.city, CountryLookup.lookup(zone.id)?.let { "${it.flag}  $label" } ?: label)
        views.setString(R.id.time, "setTimeZone", zone.id)
        views.setString(R.id.date, "setTimeZone", zone.id)
        views.setOnClickPendingIntent(
            R.id.root,
            PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        )
        manager.updateAppWidget(id, views)
    }

    private fun scheduleNextRefresh(context: Context) {
        val period = SKY_REFRESH_MINUTES * 60_000L
        val next = (System.currentTimeMillis() / period + 1) * period // next wall-clock boundary
        context.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC, next, refreshIntent(context))
    }

    private fun refreshIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, 0, Intent(context, SkyWidget::class.java).setAction(ACTION_REFRESH),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    /**
     * Widget size in px, from the launcher's reported dp (portrait: max width × min height).
     * The longest side is capped because the bitmap crosses a Binder call capped at ~1MB;
     * the sky is soft enough that the launcher's upscale isn't visible.
     */
    private fun bitmapSize(context: Context, options: Bundle): Pair<Int, Int> {
        val wDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).takeIf { it > 0 } ?: 180
        val hDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).takeIf { it > 0 } ?: 180
        val density = context.resources.displayMetrics.density
        val scale = minOf(density, MAX_BITMAP_SIDE / (max(wDp, hDp) * 1f))
        return (wDp * scale).roundToInt() to (hDp * scale).roundToInt()
    }

    companion object {
        /** Re-render every placed widget, e.g. after the saved city list changed. */
        fun refresh(context: Context) {
            context.sendBroadcast(Intent(context, SkyWidget::class.java).setAction(ACTION_REFRESH))
        }

        fun setCity(context: Context, widgetId: Int, cityId: String) {
            prefs(context).edit().putString(cityKey(widgetId), cityId).apply()
            refresh(context)
        }

        private fun prefs(context: Context) = context.getSharedPreferences("sky_widget", Context.MODE_PRIVATE)
        private fun cityKey(widgetId: Int) = "city_$widgetId"

        private const val ACTION_REFRESH = "org.surajshetty.worldclockapp.SKY_WIDGET_REFRESH"
        // ponytail: fixed cadence; the sun moves ~2% of the widget's width per 15 min.
        // Drop it if a smoother sky is worth the extra renders.
        private const val SKY_REFRESH_MINUTES = 15
        private const val MAX_BITMAP_SIDE = 600
    }
}
