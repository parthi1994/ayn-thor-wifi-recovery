# AYN Thor Wi-Fi Recovery — français

L'application automatise un contournement des pannes Wi-Fi du Thor : oublier le réseau choisi, redémarrer puis se reconnecter avec le mot de passe conservé. Elle propose aussi la connexion simple et la gestion des réseaux. Ce n'est pas un correctif firmware AYN.

[Installer l'APK](../dist/Thor-WiFi-v2.1.apk). Ouvrir Thor Wi-Fi une fois, ajouter ses réseaux, sélectionner un réseau puis choisir l'action. Le bouton **FR / EN** change la langue. **Fichier Wi-Fi et aide** explique l'utilité et les limites.

La suppression d'une entrée de la liste ne supprime pas le réseau Android. Le bouton de récupération oublie uniquement le réseau sélectionné, après confirmation. La reprise se fait par l'application au démarrage ; déverrouiller le Thor si demandé. Garder l'application installée et ne pas la forcer à l'arrêt.

Les mots de passe sont en clair dans `Téléchargements/Thor-Scripts/WIFI_RESEAUX.txt`, pour permettre une modification locale sans PC. Ils sont masqués dans l'éditeur. Les sources et l'APK ne contiennent aucun identifiant personnel. Ne pas publier son fichier de réseaux ni sa clé privée de signature.

WPA2 uniquement. Service root AYN requis ; compatibilité vérifiée sur le firmware Thor précisé dans le [README anglais](../README.md). Les autres appareils et firmwares ne sont pas garantis. Aucun PC, Shizuku ou Internet n'est nécessaire après installation.

Les captures montrent des réseaux fictifs dans le mode de démonstration. La documentation anglaise décrit les essais réels, les limites et la compilation. Les sources Java, ressources FR/EN et scripts sont incluses.
