
package tn.isetbizerte.tp4_alertes

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import android.content.pm.ServiceInfo
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class ServiceSurveillance : Service() {

    // Coroutine liée à la durée de vie du service
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var job: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        val seuil = intent?.getDoubleExtra(EXTRA_SEUIL, 40.0) ?: 40.0

        creerCanalService()
        Alertes.creerCanal(this)

        // Démarrer le service au premier plan avec une notification permanente
        ServiceCompat.startForeground(
            this,
            ID_NOTIF,
            notificationEnCours("Démarrage..."),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            else
                0
        )

        // Relancer la boucle si le seuil change
        job?.cancel()

        job = scope.launch {
            var enAlerte = false

            while (isActive) {

                val temperature = temperatureBatterie()

                Log.d(
                    "TP4",
                    "Surveillance : $temperature °C (seuil $seuil °C)"
                )

                mettreAJour(
                    "Batterie : %.1f °C (seuil %.1f °C)"
                        .format(temperature, seuil)
                )

                if (temperature >= seuil && !enAlerte) {

                    if (Alertes.autorisee(this@ServiceSurveillance)) {
                        Alertes.afficher(
                            this@ServiceSurveillance,
                            "Température élevée",
                            "Batterie à %.1f °C (seuil %.1f °C)"
                                .format(temperature, seuil)
                        )
                    }

                    enAlerte = true

                } else if (temperature < seuil) {
                    enAlerte = false
                }

                delay(10_000)
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        job?.cancel()
        scope.cancel()
        super.onDestroy()
    }

    private fun temperatureBatterie(): Double {
        val etat = registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )

        return (
            etat?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
        ) / 10.0
    }

    private fun creerCanalService() {
        val canal = NotificationChannel(
            CANAL_SERVICE,
            "Surveillance",
            NotificationManager.IMPORTANCE_LOW
        )

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(canal)
    }

    private fun notificationEnCours(texte: String): Notification {
        return NotificationCompat.Builder(this, CANAL_SERVICE)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("Surveillance active")
            .setContentText(texte)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    @SuppressLint("MissingPermission")
    private fun mettreAJour(texte: String) {
        if (Alertes.autorisee(this)) {
            NotificationManagerCompat.from(this).notify(
                ID_NOTIF,
                notificationEnCours(texte)
            )
        }
    }

    companion object {
        const val EXTRA_SEUIL = "seuil"
        private const val CANAL_SERVICE = "surveillance"
        private const val ID_NOTIF = 1
    }
}

// Canal de communication entre Flutter et le service
class ControleService(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {

        val intent = Intent(context, ServiceSurveillance::class.java)

        when (call.method) {

            "demarrer" -> {

                intent.putExtra(
                    ServiceSurveillance.EXTRA_SEUIL,
                    call.argument<Double>("seuil") ?: 40.0
                )

                ContextCompat.startForegroundService(context, intent)

                result.success(null)
            }

            "arreter" -> {

                context.stopService(intent)

                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
