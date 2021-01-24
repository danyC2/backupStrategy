## Stratégie de sauvegarde

Pour pallier sereinement au risque potentiel de perdre des données, il est judicieux de pouvoir disposer à tout instant de plusieurs copies à jour de ses données.

Je procède dorénavant ainsi:

- centralisation des données sur un serveur Debian;
- configuration des disques dur en RAID1, pour les pannes HW;
- snapshot journalier des données, pour garder un historique en local;
- synchronisation quotidienne des données, depuis une machine tierce;
- snapshot journalier sur la machine tierce, pour un historique redondant;
- sauvegarde quotidienne des données, hors site pour récupération après sinistre;
- matériel hors site identique à celui de production, comme réserve HW;
- contrôle automatique de l’intégrité des données externalisées.

Le script oHC4.sh commence par vérifier le bon fonctionnement du RAID1 et alerte en cas de besoin. Ensuite il évalue le débit de la ligne, chiffre toutes les données puis envoie les paquets chiffrés de façon sécurisée, par SSH sur le serveur hors site. Puis il crée une image (snapshot) de tous les fichiers, qu’il conserve séparément, ceci pour chacun des jours.

Une fois par semaine il contrôle l’intégrité des données sauvegardées.

La synchronisation, depuis une machine tierce, est assurée par le script oHC4rsync.sh, qui utilise rsync pour faire ce travail. Ce script réalise également, une fois par jour, des images (snapshot) de tous les fichiers synchronisés. Ainsi on dispose d’un historique redondant.

Les deux scripts décrits plus haut exploitent les technologies open source suivantes :

- OpenSSH pour communiquer de manière sûre;
- Borg pour effectuer des sauvegardes dont les données sont chiffrées avant envoi;
- rsync pour synchroniser les données rapidement, en local;
- iPerf pour mesurer le débit de la ligne;

et utilisent pour les connections SSH des clés de courbes elliptiques « Curve25519 », assurant une excellente confidentialité tout en offrant des performances particulièrement élevées.

Borg est un programme de sauvegarde par déduplication et compression. Cette technique est adaptée aux sauvegardes quotidiennes car seules les modifications sont stockées.

Le script oHC4extract.sh permet quant à lui de récupérer librement sur la machine source ou sur une nouvelle machine l’ensemble des données, un répertoire en particulier ou juste un fichier.
