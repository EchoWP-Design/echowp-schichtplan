package de.echowp.schichtplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/** Widget „Monatsübersicht“: zeigt das Bild, das die App vom aktuellen Monat zeichnet. */
class MonatWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val path = widgetData.getString("monat", null)
        val bitmap = if (path != null && File(path).exists()) BitmapFactory.decodeFile(path) else null
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_monat)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.monat_bild, bitmap)
                views.setViewVisibility(R.id.monat_bild, View.VISIBLE)
                views.setViewVisibility(R.id.monat_leer, View.GONE)
            } else {
                views.setViewVisibility(R.id.monat_bild, View.GONE)
                views.setViewVisibility(R.id.monat_leer, View.VISIBLE)
            }
            views.setOnClickPendingIntent(
                R.id.monat_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
