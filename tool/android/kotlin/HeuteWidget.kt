package de.echowp.schichtplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Widget „Schichten heute“: heute und morgen, je Person die Schicht oder „frei“. */
class HeuteWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val days = try {
            JSONObject(widgetData.getString("tage", null) ?: "{}")
        } catch (e: Exception) {
            JSONObject()
        }
        val today = Calendar.getInstance()
        val tomorrow = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, 1) }
        val title = SimpleDateFormat("EEEE, d. MMMM", Locale.GERMANY).format(today.time)

        val text = SpannableStringBuilder()
        appendDay(text, days, today)
        text.append("\n")
        bold(text, "Morgen")
        text.append("\n")
        appendDay(text, days, tomorrow)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_heute)
            views.setTextViewText(R.id.heute_titel, title)
            views.setTextViewText(R.id.heute_text, text)
            views.setOnClickPendingIntent(
                R.id.heute_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun key(c: Calendar): String =
        String.format(Locale.ROOT, "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))

    private fun appendDay(out: SpannableStringBuilder, days: JSONObject, day: Calendar) {
        val list = days.optJSONArray(key(day))
        if (list == null) {
            out.append("Keine Daten – App einmal öffnen\n")
            return
        }
        for (i in 0 until list.length()) {
            val p = list.optJSONObject(i) ?: continue
            val start = out.length
            out.append("● ")
            out.setSpan(ForegroundColorSpan(p.optInt("c", -1)), start, start + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            bold(out, p.optString("n"))
            out.append(": ").append(p.optString("t")).append("\n")
        }
    }

    private fun bold(out: SpannableStringBuilder, s: String) {
        val start = out.length
        out.append(s)
        out.setSpan(StyleSpan(Typeface.BOLD), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
}
