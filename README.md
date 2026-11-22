# Terres de Viking : mods VikingLands et mode HD

Ce depot ne contient pas de code source : il heberge, dans ses **Releases**, les fichiers compiles a installer dans
Valheim (les 8 DLL VikingLands et les donnees du mode HD), le manifeste qui les decrit et les scripts de mise a jour.

Le depot s'appelait auparavant `TDV-VikingLands-HD` : les anciennes adresses redirigent ici.

## Mettre son jeu a jour : TDV-Sync.bat

1. Telecharger `TDV-Sync.bat` (derniere Release) et le poser dans le dossier de Valheim, a cote de `valheim.exe`.
2. Fermer Valheim, puis double-cliquer sur `TDV-Sync.bat`.

Le script compare chaque fichier installe au manifeste (empreinte SHA-256) et ne telecharge que ce qui a change :
les 8 DLL `BepInEx/plugins/VikingLands.*.dll` et les donnees `BepInEx/plugins/VikingLands.HD/` (10,3 Go installes,
environ 4 Go a telecharger la premiere fois). Chaque fichier telecharge est verifie avant de remplacer l'ancien.
Le mode HD reste desactive dans le jeu tant que le joueur ne coche pas « Mode HD » dans Parametres > Graphismes.

Depuis la 1.5.8, `TDV-Sync.bat` se met a jour tout seul : s'il existe une nouvelle version du script, il la
telecharge, la verifie, se remplace et se relance, puis continue la mise a jour. Il suffit donc de le telecharger une
fois. Un `TDV-Sync.bat` plus ancien recupere aussi la nouvelle version au premier lancement.

## Serveur Linux : TDV-Sync-Server.sh

Met a jour seulement les 7 DLL serveur (groupe `mods` du manifeste) : ni la DLL HD ni les packs HD. Serveur arrete :

```bash
curl -fLO https://github.com/talath62/TDV-VikingLands-Release/releases/latest/download/TDV-Sync-Server.sh
bash TDV-Sync-Server.sh /chemin/vers/BepInEx/plugins
```

Sans argument, le script prend `./BepInEx/plugins` ou l'unique instance AMP qui contient `VikingLands.Core.dll`. Les
DLL remplacees sont gardees dans `BepInEx/tdv-sync-backup/<date>/`.

Depuis la 1.5.8, `TDV-Sync-Server.sh` se met aussi a jour tout seul. **Un script telecharge avant la 1.5.8 ne sait
pas se remplacer : le retelecharger une fois avec la commande ci-dessus.**

## Manifeste

`https://github.com/talath62/TDV-VikingLands-Release/releases/latest/download/tdv-manifest.json`

Pour chaque fichier : chemin d'installation (`path`, relatif au dossier de Valheim), groupe (`mods` pour tous,
`hd` pour le mode HD), taille, SHA-256, adresse du `.gz` a telecharger et son empreinte. La section `scripts` decrit
`TDV-Sync.bat` et `TDV-Sync-Server.sh` (mise a jour automatique). Une nouvelle version ne publie que les fichiers
modifies ; les autres restent dans leur Release d'origine, qui doit donc rester en ligne.

## Notes de version

Chaque Release porte ses notes de version (nouveautes et deploiement) dans sa description.

Textures HD d'origine : HD Valheim Textures et Badgers HD Terrain (Nexus Mods), redistribuees avec l'accord de leurs
auteurs.
