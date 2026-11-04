#!/bin/sh
# Run the project with Godot 4.7.2; this is not an exported native game.
set -eu
PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERSION=4.7.2
NAME=Godot_v4.7.2-stable_linux.x86_64
ARCHIVE="$NAME.zip"
EXPECTED=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
URL="https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/$ARCHIVE"
CACHE="${XDG_DATA_HOME:-$HOME/.local/share}/ComeToMe/Godot-$VERSION"

if [ "${GODOT_BIN:-}" ]; then
    GODOT=$GODOT_BIN
elif [ -x "$PROJECT/$NAME" ]; then
    GODOT="$PROJECT/$NAME"
elif [ -x "$CACHE/$NAME" ]; then
    GODOT="$CACHE/$NAME"
else
    mkdir -p "$CACHE"
    if [ -f "$PROJECT/$ARCHIVE" ]; then
        ZIP="$PROJECT/$ARCHIVE"
    else
        ZIP="$CACHE/$ARCHIVE"
        echo 'A descarregar o Godot oficial 4.7.2 para Linux (~78 MB).'
        if command -v curl >/dev/null 2>&1; then
            curl --fail --location --retry 2 --output "$ZIP.part" "$URL"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$ZIP.part" "$URL"
        else
            echo 'E necessario curl ou wget, ou forneca o ZIP oficial ao lado do projeto.' >&2
            exit 1
        fi
        mv -f "$ZIP.part" "$ZIP"
    fi
    if ! command -v sha256sum >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
        echo 'E necessario sha256sum e unzip para instalar o Godot.' >&2
        exit 1
    fi
    printf '%s  %s\n' "$EXPECTED" "$ZIP" | sha256sum -c -
    unzip -o -q "$ZIP" -d "$CACHE"
    chmod +x "$CACHE/$NAME"
    GODOT="$CACHE/$NAME"
fi
if [ ! -x "$GODOT" ]; then
    echo "Godot nao executavel: $GODOT" >&2
    exit 1
fi
case "$("$GODOT" --version)" in
    4.7.2.*) ;;
    *) echo "Este projeto foi testado com Godot $VERSION. Binario indicado: $GODOT" >&2; exit 1 ;;
esac
printf '%s\n' 'A importar recursos do projeto...'
"$GODOT" --headless --path "$PROJECT" --editor --import
printf '%s\n' 'A iniciar Come To Me...'
exec "$GODOT" --path "$PROJECT" "$@"
