# Terres de Viking : données du mode HD

Ce dépôt ne contient pas de code : il héberge, dans ses **Releases**, les données du mode HD optionnel de Terres de
Viking (mod client VikingLands.HD), installées par le launcher quand le joueur coche « Mode HD ».

- Chaque Release contient des fichiers `.gz` (textures HD découpées en morceaux de moins de 2 Go) et
  `hd-manifest.json`, qui donne pour chaque fichier son chemin d'installation, sa taille et son empreinte SHA-256.
- Manifeste de la dernière version :
  `https://github.com/talath62/TDV-VikingLands-HD/releases/latest/download/hd-manifest.json`
- Un fichier déjà installé avec la même empreinte n'est pas retéléchargé ; une nouvelle version ne publie que les
  fichiers qui ont changé, les autres restent dans leur Release d'origine.

Installation à la main : télécharger les `.gz` de la Release, les décompresser (7-Zip) et placer chaque fichier au
chemin indiqué dans le manifeste (`path`, relatif au dossier de Valheim).

Textures d'origine : HD Valheim Textures et Badgers HD Terrain (Nexus Mods), redistribuées avec l'accord de leurs
auteurs.
