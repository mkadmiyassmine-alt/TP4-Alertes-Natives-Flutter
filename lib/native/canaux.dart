
import 'package:flutter/services.dart';

class CanauxNatifs {
  static const _alerte = MethodChannel('alerte/notifier');
  static const _sync = MethodChannel('sync/planifier');
  static const _service = MethodChannel('service/surveillance');

  // Demander la permission des notifications
  static Future<bool> demanderPermissionNotif() async {
    return await _alerte.invokeMethod<bool>(
          'demanderPermission',
        ) ??
        false;
  }

  // Envoyer une notification native
  static Future<int?> notifier(String titre, String texte) {
    return _alerte.invokeMethod<int>(
      'notifier',
      {
        'titre': titre,
        'texte': texte,
      },
    );
  }

  // Récupérer une action lors du démarrage de l'application
  static Future<Map<String, dynamic>?> actionInitiale() {
    return _alerte.invokeMapMethod<String, dynamic>(
      'actionInitiale',
    );
  }

  // Écouter les actions lorsque l'application est déjà ouverte
  static void ecouterActions(
    void Function(Map<String, dynamic>) traiter,
  ) {
    _alerte.setMethodCallHandler((call) async {
      if (call.method == 'surAction') {
        traiter(
          Map<String, dynamic>.from(call.arguments as Map),
        );
      }
    });
  }

  // Planifier une vérification périodique de la batterie
  static Future<void> planifier(int seuil) {
    return _sync.invokeMethod(
      'planifier',
      {'seuil': seuil},
    );
  }

  // Vérifier immédiatement le niveau de batterie
  static Future<void> verifierMaintenant(int seuil) {
    return _sync.invokeMethod(
      'maintenant',
      {'seuil': seuil},
    );
  }

  // Annuler la vérification périodique
  static Future<void> annulerPlanification() {
    return _sync.invokeMethod('annuler');
  }

  // Démarrer la surveillance continue
  static Future<void> demarrerSurveillance(double seuil) {
    return _service.invokeMethod(
      'demarrer',
      {'seuil': seuil},
    );
  }

  // Arrêter la surveillance continue
  static Future<void> arreterSurveillance() {
    return _service.invokeMethod('arreter');
  }
}
