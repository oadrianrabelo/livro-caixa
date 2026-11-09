package io.github.oadrianrabelo.livrocaixa

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Widget da tela inicial. Os textos vêm do app (lib/platform/extras.dart).
class LivroWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.livro_widget).apply {
                setTextViewText(R.id.widget_month, widgetData.getString("month", "Livro-Caixa"))
                setTextViewText(R.id.widget_available, widgetData.getString("available", "R$ —"))
                setTextViewText(R.id.widget_left, widgetData.getString("left", ""))
                setTextViewText(R.id.widget_unpaid, widgetData.getString("unpaid", ""))
                // Tocar no widget abre o app.
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
