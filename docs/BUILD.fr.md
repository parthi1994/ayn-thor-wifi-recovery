# Thor Wi-Fi 2.1 — sources

Application Android locale pour gérer une liste de réseaux WPA2 et reprendre automatiquement une connexion après un oubli volontaire et un redémarrage. Interface française et anglaise, adaptée au paysage et au portrait. Package : `local.thor.wifiresume`.

## Installer et utiliser

Installer `Thor-WiFi.apk` sur un AYN Thor, puis ouvrir **Thor Wi-Fi** une fois. L'APK installe ses propres moteurs et lanceurs via le même service root AYN que « Run script as root ». Elle ne nécessite ni PC après installation, ni Shizuku, ni Internet. Garder l'application installée et ne pas la forcer à l'arrêt pour recevoir le démarrage.

Compatibilité réellement vérifiée : AYN Thor, Android 13, firmware `Thor_V1.0.0.377_20260206_165408_user`, utilisateur Android principal. L'accès repose sur le service Binder AYN `PServerBinder`, transaction 0. Ce n'est pas une application root universelle : d'autres appareils ou firmwares peuvent ne pas exposer cette interface. La compatibilité minimale du paquet est Android 8 ; cela ne prouve pas la compatibilité du service AYN sur d'autres versions.

- **Ajouter / Modifier / Supprimer** : gère les entrées de l'application et le fichier `Téléchargements/Thor-Scripts/WIFI_RESEAUX.txt`. Supprimer ici ne supprime pas le réseau enregistré dans Android.
- **Connus d'Android** : sélectionne un SSID déjà enregistré. Si le mot de passe n'est pas dans la liste de l'application, il faut le saisir une fois. L'application n'extrait pas les mots de passe du magasin Android.
- **Se connecter** : connecte uniquement le réseau sélectionné, sans oubli ni reboot.
- **Oublier, redémarrer et reconnecter** : affiche une confirmation nommant le réseau, puis oublie uniquement ce SSID, vérifie l'oubli, redémarre et reprend automatiquement. Aucun reset usine. Un déverrouillage après reboot peut être nécessaire.

Le fichier texte local est volontairement en clair, pour permettre une modification directe hors ligne. Les mots de passe sont masqués par défaut dans l'éditeur. Ni l'APK ni ces sources ne contiennent de réseau personnel. Pour partager, envoyer l'APK ou cette archive de sources, pas le fichier WIFI_RESEAUX.txt.

## Construire sous Windows

Outils requis : PowerShell 7, JDK 17 ou supérieur, SDK Android avec `android.jar` API 33 et build-tools contenant `aapt`, `zipalign`, `apksigner`, plus le compilateur D8/R8 (`r8.jar`). Aucun gestionnaire de dépendances ni téléchargement n'est exécuté par le script.

```powershell
./build.ps1 -JavaHome 'C:\chemin\jdk' `
  -BuildTools 'C:\chemin\android-sdk\build-tools\34.0.0' `
  -AndroidJar 'C:\chemin\android-sdk\platforms\android-33\android.jar' `
  -R8Jar 'C:\chemin\r8.jar'
```

Sortie : `../Build/Thor-WiFi.apk`. À défaut du paramètre `-KeyStore`, le script crée une clé locale dans ce dossier, alias `thor-local`, mot de passe de développement `changeit`. Conserver cette clé en privé pour signer les prochaines mises à jour ; une nouvelle clé ne peut pas mettre à jour l'APK existante. La clé utilisée pour l'APK distribuée n'est pas incluse dans les sources à partager.

Construction de référence : JDK 20, Android API 33, build-tools 34.0.0 et R8 8.7.18. Signature APK v2/v3 vérifiée. L'APK utilise uniquement les API Android natives et des scripts shell locaux.

## Organisation

- `java/.../MainActivity.java` : interface, tâches en arrière-plan, validation/synchronisation.
- `NetworkStore.java` : parseur littéral et validation SSID/mot de passe, indépendant d'Android.
- `ThorBridge.java` : commandes Binder fixes. Aucun SSID/mot de passe interpolé dans la commande root.
- `BootReceiver.java` : reprend seulement une opération précédemment demandée.
- `assets/install.sh` : installe les moteurs embarqués au premier lancement et après mise à jour ; conserve les identifiants existants.
- `assets/engine/app_api.sh` : échanges via fichiers privés de l'application, gestion du catalogue et de la sélection.
- `assets/engine/workflow.sh` : ciblage exact du SSID, oubli vérifié, marqueur de reprise et exécution ponctuelle.
- `assets/launchers/` : lanceurs manuels compatibles Thor Settings.
- `tests/` : tests du parseur, de l'API shell isolée et scénario UI Android utilisant une entrée fictive temporaire.

La copie privée des identifiants, root:root 600 dans un dossier 700, sert à la reprise. Le catalogue public contient toute la liste ; la copie de reprise contient seulement la sélection lors d'une action dans l'application. Les modifications sont refusées pendant une opération en attente. Aucune commande de connexion PC n'est nécessaire au boot.

Limites : WPA2-PSK uniquement, phrases de 8 à 63 caractères ASCII imprimables, SSID de 1 à 32 octets UTF-8 sans caractères de contrôle ni espaces aux extrémités. WPA3 seul, réseaux cachés et Enterprise ne sont pas gérés. L'argument système `cmd wifi connect-network` reçoit nécessairement le mot de passe ; les scripts suppriment sa sortie et ne l'impriment pas, sans pouvoir garantir le comportement des logs du firmware.

Les tests simulés ne redémarrent aucun appareil. `UiTestRunner.java` est un test d'instrumentation séparé, exclu de l'APK finale ; il exerce les vrais boutons ajouter/sélectionner/modifier/supprimer puis restaure le nombre d'entrées initial. Le rapport livré avec l'APK distingue ces tests du cycle réel.
