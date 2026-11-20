#!/usr/bin/env bash
# TDV-Sync-Server.sh : met a jour les DLL des mods VikingLands d'un serveur Valheim (Linux) d'apres le manifeste publie.
# Seulement le groupe "mods" (les DLL serveur) : ni la DLL HD ni les packs HD, qui ne servent qu'aux joueurs.
#
#   bash TDV-Sync-Server.sh [dossier BepInEx/plugins]
#
# Sans argument : ./BepInEx/plugins, sinon l'unique instance AMP qui contient VikingLands.Core.dll.
# Le serveur doit etre ARRETE. Les DLL remplacees sont gardees dans BepInEx/tdv-sync-backup/<date>/ (hors plugins).
# Ne telecharge que les DLL dont l'empreinte SHA-256 differe du manifeste ; chaque fichier est verifie avant d'etre pose.
# Outils : bash, curl (ou wget), sha256sum, gzip, awk.
set -u

MANIFEST_URL="${TDV_MANIFEST:-https://github.com/talath62/TDV-VikingLands-HD/releases/latest/download/tdv-manifest.json}"

die() { echo "ERREUR : $1" >&2; exit "${2:-1}"; }

for tool in sha256sum gzip awk; do command -v "$tool" >/dev/null 2>&1 || die "outil $tool absent"; done
if command -v curl >/dev/null 2>&1; then
    fetch() { curl -fsSL --retry 3 --retry-delay 2 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
    fetch() { wget -q --tries=3 -O "$2" "$1"; }
else
    die "ni curl ni wget"
fi

# --- Dossier plugins ---------------------------------------------------------------------------------------------
plugins="${1:-}"
if [ -z "$plugins" ]; then
    if [ -d "./BepInEx/plugins" ]; then
        plugins="./BepInEx/plugins"
    else
        mapfile -t found < <(ls -d /home/amp/.ampdata/instances/*/Valheim/*/BepInEx/plugins 2>/dev/null | while read -r d; do [ -f "$d/VikingLands.Core.dll" ] && echo "$d"; done)
        if [ "${#found[@]}" -eq 1 ]; then
            plugins="${found[0]}"
        elif [ "${#found[@]}" -gt 1 ]; then
            printf '  %s\n' "${found[@]}" >&2
            die "plusieurs serveurs trouves : donnez le dossier plugins en argument" 2
        else
            die "dossier BepInEx/plugins introuvable : donnez-le en argument" 2
        fi
    fi
fi
[ -d "$plugins" ] || die "$plugins n'est pas un dossier" 2
plugins="$(cd "$plugins" && pwd)"
case "$plugins" in */BepInEx/plugins) ;; *) die "$plugins ne se termine pas par BepInEx/plugins" 2 ;; esac
root="${plugins%/BepInEx/plugins}"
echo "Terres de Viking : mise a jour des DLL VikingLands du serveur"
echo "Dossier : $plugins"

# --- Serveur arrete ? ---------------------------------------------------------------------------------------------
if command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -f valheim_server 2>/dev/null); do
        exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
        cwd="$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)"
        if [ -z "$exe$cwd" ]; then
            [ "${TDV_FORCE:-0}" = 1 ] || die "un serveur Valheim tourne (processus $pid, impossible de savoir lequel) : arretez-le, ou TDV_FORCE=1 si c'est un autre serveur" 3
        elif [[ "$exe" == "$root"/* || "$cwd" == "$root"* ]]; then
            die "ce serveur tourne encore (processus $pid) : arretez-le dans AMP avant la mise a jour" 3
        fi
    done
fi

# --- Manifeste ----------------------------------------------------------------------------------------------------
tmp="$(mktemp -d)" || die "mktemp"
trap 'rm -rf "$tmp"' EXIT
fetch "$MANIFEST_URL" "$tmp/manifest.json" || die "manifeste introuvable : $MANIFEST_URL" 4
version="$(sed -n 's/^  "version": "\(.*\)",$/\1/p' "$tmp/manifest.json" | head -n1)"
echo "Version publiee : ${version:-?}"

# Une ligne par fichier du groupe mods : chemin, taille, sha256, url, sha256 du .gz (manifeste ecrit par hd_pack decouper,
# une propriete par ligne).
awk '
    function val(line) { sub(/^[^:]*: */, "", line); sub(/,$/, "", line); gsub(/^"|"$/, "", line); return line }
    /"files": \[/ { infiles = 1 } /"delete": \[/ { infiles = 0 }
    infiles && /"path":/ { path = val($0); grp = ""; size = ""; sha = ""; url = "" }
    infiles && /"group":/ { grp = val($0) }
    infiles && /"size":/ { size = val($0) }
    infiles && /"sha256":/ { sha = val($0) }
    infiles && /"url":/ { url = val($0) }
    infiles && /"downloadSha256":/ { if (grp == "mods") print path "\t" size "\t" sha "\t" url "\t" val($0) }
' "$tmp/manifest.json" > "$tmp/mods.tsv"
count="$(wc -l < "$tmp/mods.tsv")"
[ "$count" -gt 0 ] || die "aucune DLL du groupe mods dans le manifeste" 4

# --- Mise a jour --------------------------------------------------------------------------------------------------
backup="$root/BepInEx/tdv-sync-backup/$(date +%Y%m%d-%H%M%S)"
updated=0; uptodate=0; failed=0
while IFS=$'\t' read -r path size sha url gzsha; do
    case "$path" in BepInEx/plugins/*) ;; *) echo "  ignore (hors plugins) : $path"; continue ;; esac
    name="${path#BepInEx/plugins/}"
    dest="$plugins/$name"
    if [ -f "$dest" ] && [ "$(stat -c %s "$dest")" = "$size" ] && [ "$(sha256sum "$dest" | cut -d' ' -f1)" = "$sha" ]; then
        uptodate=$((uptodate + 1)); continue
    fi
    echo "Telechargement : $name"
    ok=0
    for try in 1 2 3; do
        if fetch "$url" "$tmp/dl.gz" \
            && [ "$(sha256sum "$tmp/dl.gz" | cut -d' ' -f1)" = "$gzsha" ] \
            && gzip -dc "$tmp/dl.gz" > "$tmp/new" \
            && [ "$(sha256sum "$tmp/new" | cut -d' ' -f1)" = "$sha" ]; then
            ok=1; break
        fi
        echo "  essai $try echoue"
    done
    if [ "$ok" != 1 ]; then failed=$((failed + 1)); echo "  ECHEC : $name"; continue; fi
    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        mkdir -p "$backup" && cp -p "$dest" "$backup/$name" || { failed=$((failed + 1)); echo "  ECHEC sauvegarde : $name"; continue; }
        chown --reference="$dest" "$tmp/new" 2>/dev/null; chmod --reference="$dest" "$tmp/new" 2>/dev/null
    else
        chown --reference="$plugins" "$tmp/new" 2>/dev/null; chmod 644 "$tmp/new"
    fi
    if mv -f "$tmp/new" "$dest"; then updated=$((updated + 1)); echo "  ok"; else failed=$((failed + 1)); echo "  ECHEC : $name"; fi
done < "$tmp/mods.tsv"

echo
echo "$uptodate DLL deja a jour, $updated mise(s) a jour, $failed echec(s)."
if [ -d "$backup" ]; then echo "Anciennes DLL gardees dans $backup"; fi
if [ "$failed" -gt 0 ]; then echo "Relancez le script."; exit 1; fi
echo "Termine : version ${version:-?}. Vous pouvez redemarrer le serveur."
exit 0
