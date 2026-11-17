
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native/canaux.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PageAlertes(),
    ),
  );
}

class PageAlertes extends StatefulWidget {
  const PageAlertes({super.key});

  @override
  State<PageAlertes> createState() => _PageAlertesState();
}

class _PageAlertesState extends State<PageAlertes> {
  String _derniereAction = 'aucune';

  double _seuilBatterie = 20;
  double _seuilTemp = 40;

  bool _surveillance = false;

  @override
  void initState() {
    super.initState();

    CanauxNatifs.ecouterActions(_traiterAction);

    CanauxNatifs.actionInitiale().then((a) {
      if (a != null && mounted) {
        _traiterAction(a);
      }
    });
  }

  // Afficher l'action reçue
  void _traiterAction(Map<String, dynamic> a) {
    if (!mounted) return;

    setState(() {
      _derniereAction =
          '${a['action']} : ${a['titre']} (id ${a['id']})';
    });
  }

  // Afficher un message
  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texte)),
    );
  }

  // Demander la permission
  Future<void> _autoriser() async {
    try {
      final ok = await CanauxNatifs.demanderPermissionNotif();

      _message(
        ok ? 'Notifications autorisées' : 'Notifications refusées',
      );
    } on PlatformException catch (e) {
      _message('Erreur : ${e.message}');
    }
  }

  // Envoyer une notification
  Future<void> _envoyerAlerte() async {
    try {
      final id = await CanauxNatifs.notifier(
        'Patient critique',
        'Fréquence cardiaque : 142 bpm',
      );

      _message('Alerte envoyée (id $id)');
    } on PlatformException catch (e) {
      _message('Erreur ${e.code} : ${e.message}');
    }
  }

  // Planifier la vérification périodique
  Future<void> _planifier() async {
    try {
      await CanauxNatifs.planifier(_seuilBatterie.round());
      _message('Surveillance planifiée toutes les 15 minutes');
    } on PlatformException catch (e) {
      _message('Erreur : ${e.message}');
    }
  }

  // Vérifier immédiatement
  Future<void> _verifierMaintenant() async {
    try {
      await CanauxNatifs.verifierMaintenant(
        _seuilBatterie.round(),
      );
      _message('Vérification de la batterie demandée');
    } on PlatformException catch (e) {
      _message('Erreur : ${e.message}');
    }
  }

  // Annuler la planification
  Future<void> _annuler() async {
    try {
      await CanauxNatifs.annulerPlanification();
      _message('Surveillance périodique annulée');
    } on PlatformException catch (e) {
      _message('Erreur : ${e.message}');
    }
  }

  // Démarrer ou arrêter le Foreground Service
  Future<void> _basculerSurveillance(bool actif) async {
    try {
      if (actif) {
        await CanauxNatifs.demarrerSurveillance(_seuilTemp);
        _message('Surveillance continue démarrée');
      } else {
        await CanauxNatifs.arreterSurveillance();
        _message('Surveillance continue arrêtée');
      }

      if (mounted) {
        setState(() {
          _surveillance = actif;
        });
      }
    } on PlatformException catch (e) {
      _message('Erreur ${e.code} : ${e.message}');
    }
  }

  Widget _carte(String titre, List<Widget> contenu) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...contenu,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TP 4 – Alertes natives'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte 1 : Notifications natives
          _carte('1. Notification native', [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _autoriser,
                  child: const Text('Autoriser'),
                ),
                FilledButton(
                  onPressed: _envoyerAlerte,
                  child: const Text('Envoyer une alerte'),
                ),
              ],
            ),
          ]),

          // Carte 2 : Actions des notifications
          _carte('2. Dernière action reçue de la notification', [
            Text(_derniereAction),
          ]),

          // Carte 3 : WorkManager
          _carte('3. Surveillance automatique de la batterie', [
            Text(
              'Seuil de batterie : ${_seuilBatterie.round()} %',
            ),
            Slider(
              value: _seuilBatterie,
              min: 5,
              max: 100,
              divisions: 19,
              label: '${_seuilBatterie.round()} %',
              onChanged: (valeur) {
                setState(() {
                  _seuilBatterie = valeur;
                });
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _planifier,
                  child: const Text('Planifier'),
                ),
                OutlinedButton(
                  onPressed: _verifierMaintenant,
                  child: const Text('Vérifier maintenant'),
                ),
                OutlinedButton(
                  onPressed: _annuler,
                  child: const Text('Annuler'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'WorkManager vérifie le niveau de batterie '
              'périodiquement, avec un intervalle minimum de 15 minutes.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ]),

          // Carte 4 : Foreground Service
          _carte(
            '4. Surveillance continue (service au premier plan)',
            [
              Text(
                'Alerte si température ≥ ${_seuilTemp.round()} °C',
              ),

              Slider(
                value: _seuilTemp,
                min: 20,
                max: 50,
                divisions: 30,
                label: '${_seuilTemp.round()} °C',
                onChanged: (valeur) {
                  setState(() {
                    _seuilTemp = valeur;
                  });
                },
                onChangeEnd: (valeur) {
                  if (_surveillance) {
                    CanauxNatifs.demarrerSurveillance(valeur)
                        .catchError((e) {
                      if (mounted) {
                        _message('Erreur : $e');
                      }
                    });
                  }
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Surveillance'),
                subtitle: Text(
                  _surveillance
                      ? 'Service actif'
                      : 'Service arrêté',
                ),
                value: _surveillance,
                onChanged: _basculerSurveillance,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
