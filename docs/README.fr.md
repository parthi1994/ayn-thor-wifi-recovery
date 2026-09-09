# AYN Thor Wi-Fi Recovery — français

L'application automatise un contournement des pannes Wi-Fi du Thor : oublier tous les réseaux enregistrés dans Android, redémarrer puis se reconnecter avec le mot de passe conservé. Elle propose aussi la connexion simple et la gestion des réseaux. Ce n'est pas un correctif firmware AYN.

[Installer l'APK](../dist/Thor-WiFi-v2.3.apk). Ouvrir Thor Wi-Fi une fois, ajouter ses réseaux, sélectionner un réseau puis choisir l'action. Le bouton **FR / EN** change la langue. **Fichier Wi-Fi et aide** explique l'utilité et les limites.

La suppression d'une entrée de la liste ne supprime pas le réseau Android. Le bouton de récupération oublie **tous les réseaux Android**, après confirmation, puis reconnecte le réseau choisi. La liste de l’application et ses mots de passe sont conservés. Les réseaux absents de cette liste devront être ajoutés à nouveau. La reprise se fait par l'application au démarrage ; déverrouiller le Thor si demandé. Garder l'application installée et ne pas la forcer à l'arrêt.

Les mots de passe sont en clair dans `Téléchargements/Thor-Scripts/WIFI_RESEAUX.txt`, pour permettre une modification locale sans PC. Ils sont masqués dans l'éditeur. Les sources et l'APK ne contiennent aucun identifiant personnel. Ne pas publier son fichier de réseaux ni sa clé privée de signature.

**WPA2-PSK et WPA3-SAE**, détectés automatiquement dans les scans, selon les commandes disponibles sur le firmware. Une box Wi-Fi 7 peut accepter une connexion compatible, mais l’application ne transforme pas la radio du Thor en Wi-Fi 7. Réseaux masqués, ouverts et Enterprise non pris en charge ; mots de passe de 8 à 63 caractères ASCII imprimables. La sécurité observée est conservée avant le reboot pour permettre la reprise même si le scan est vide au démarrage. Si elle est inconnue, la récupération s’arrête avant tout oubli : ouvrir les paramètres Wi-Fi pour détecter le réseau d’abord.

Un essai réel a confirmé une connexion **Wi-Fi 7 (802.11be), WPA3-SAE, en 6 GHz**, avec une adresse IP, après mise à jour du profil enregistré. Cela ne garantit pas toutes les box. Le cycle complet oubli/redémarrage/reconnexion a été vérifié séparément sur le réseau habituel.

**Connecté ✓** identifie le réseau réellement associé avec une adresse IP ; cela ne teste pas Internet. L’état est vérifié à l’ouverture et avec **Actualiser**. Pendant une connexion ou récupération, les vérifications restent discrètes : elles ne désactivent pas les boutons et ne reconstruisent pas une liste inchangée. Aucune actualisation périodique au repos.

Tous les scripts nécessaires sont **inclus dans l’APK** et installés au premier lancement. Service root AYN requis ; compatibilité vérifiée sur le firmware Thor précisé dans le [README anglais](../README.md). Les autres appareils et firmwares ne sont pas garantis. Aucun PC, Shizuku ou Internet n'est nécessaire après installation.

Les captures montrent des réseaux fictifs dans le mode de démonstration. La documentation anglaise décrit les essais réels, les limites et la compilation. Les sources Java, ressources FR/EN et scripts sont incluses.

Version 2.3 : une opération dont le processus a disparu est signalée comme interrompue et peut être relancée. Le marqueur périmé est retiré au prochain contrôle, après un délai de lancement de 15 secondes. Une reconnexion est limitée à 150 secondes par profil. Ces garde-fous ne lancent pas de nouveau reboot automatiquement. Sur le Thor réel, la mise à jour a débloqué un ancien état, puis le cycle complet depuis l’application a reconnecté le réseau avec une adresse IP après reboot, sans commande de reprise PC et sans modifier le fichier des profils.
