# Terres de Viking : mods VikingLands et mode HD

Ce depot ne contient pas de code source : il heberge, dans ses **Releases**, les fichiers compiles a installer dans
Valheim (les 8 DLL VikingLands et les donnees du mode HD), le manifeste qui les decrit et le script de mise a jour.

## Mettre son jeu a jour : TDV-Sync.bat

1. Telecharger `TDV-Sync.bat` (derniere Release) et le poser dans le dossier de Valheim, a cote de `valheim.exe`.
2. Fermer Valheim, puis double-cliquer sur `TDV-Sync.bat`.

Le script compare chaque fichier installe au manifeste (empreinte SHA-256) et ne telecharge que ce qui a change :
les 8 DLL `BepInEx/plugins/VikingLands.*.dll` et les donnees `BepInEx/plugins/VikingLands.HD/` (9,6 Go installes,
environ 3,9 Go a telecharger la premiere fois). Chaque fichier telecharge est verifie avant de remplacer l'ancien.
Le mode HD reste desactive dans le jeu tant que le joueur ne coche pas « Mode HD » dans Parametres > Graphismes.

## Serveur Linux : TDV-Sync-Server.sh

Met a jour seulement les 7 DLL serveur (groupe `mods` du manifeste) : ni la DLL HD ni les packs HD. Serveur arrete :

```bash
curl -fLO https://github.com/talath62/TDV-VikingLands-HD/releases/latest/download/TDV-Sync-Server.sh
bash TDV-Sync-Server.sh /chemin/vers/BepInEx/plugins
```

Sans argument, le script prend `./BepInEx/plugins` ou l'unique instance AMP qui contient `VikingLands.Core.dll`. Les
DLL remplacees sont gardees dans `BepInEx/tdv-sync-backup/<date>/`.

## Manifeste

`https://github.com/talath62/TDV-VikingLands-HD/releases/latest/download/tdv-manifest.json`

Pour chaque fichier : chemin d'installation (`path`, relatif au dossier de Valheim), taille, SHA-256, adresse du `.gz`
a telecharger et son empreinte. Une nouvelle version ne publie que les fichiers modifies ; les autres restent dans leur
Release d'origine, qui doit donc rester en ligne.

Textures HD d'origine : HD Valheim Textures et Badgers HD Terrain (Nexus Mods), redistribuees avec l'accord de leurs
auteurs.
