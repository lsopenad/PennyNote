#!/usr/bin/env python3
# Genera PennyNote/Resources/EmojiCatalog.json, el catálogo del selector de icono de las categorías.
#
# iOS no publica la lista de emojis, así que se saca de los datos oficiales de Unicode:
# - emoji-test.txt: qué emojis hay, en qué orden y en qué grupo.
# - Anotaciones de CLDR: nombre y palabras clave en cada idioma de la app, para el buscador y VoiceOver.
#
# La versión de emoji es la más alta que sabe dibujar el iOS mínimo de la app (iOS 18.0 → Emoji 15.1).
# Al subir el deploymentTarget de project.yml, subir aquí EMOJI_VERSION y CLDR_VERSION (la de CLDR que
# trae los nombres de esa versión de emoji) y volver a ejecutar:
#
#     python3 scripts/generate-emoji-catalog.py

import json
import pathlib
import subprocess

EMOJI_VERSION = "15.1"
CLDR_VERSION = "44.1.0"

EMOJI_TEST_URL = f"https://www.unicode.org/Public/emoji/{EMOJI_VERSION}/emoji-test.txt"
CLDR_BASE_URL = f"https://raw.githubusercontent.com/unicode-org/cldr-json/{CLDR_VERSION}/cldr-json"

# Idioma de la app → idioma de CLDR.
LANGUAGES = {"es": "es", "en": "en", "zh-Hans": "zh"}

# Grupos de emoji-test.txt → id que entiende EmojiGroup en la app. "Component" (tonos de piel y pelo
# sueltos) no es un emoji que se pueda elegir.
GROUPS = {
    "Smileys & Emotion": "smileys",
    "People & Body": "people",
    "Animals & Nature": "nature",
    "Food & Drink": "food",
    "Travel & Places": "travel",
    "Activities": "activities",
    "Objects": "objects",
    "Symbols": "symbols",
    "Flags": "flags",
}

# Modificadores de tono de piel: los iconos van siempre en el tono por defecto.
SKIN_TONES = {chr(code) for code in range(0x1F3FB, 0x1F400)}
VARIATION_SELECTOR = "️"

OUTPUT = pathlib.Path(__file__).resolve().parent.parent / "PennyNote" / "Resources" / "EmojiCatalog.json"


# Con curl y no con urllib: el Python de python.org no trae certificados y falla al conectar por HTTPS.
def fetch(url):
    return subprocess.run(["curl", "-sfL", url], check=True, capture_output=True).stdout.decode("utf-8")


def parse_emoji_test(text):
    groups = []
    current = None
    for line in text.splitlines():
        if line.startswith("# group:"):
            name = line.removeprefix("# group:").strip()
            current = None
            if name in GROUPS:
                current = {"id": GROUPS[name], "emojis": []}
                groups.append(current)
            continue
        if current is None or not line or line.startswith("#"):
            continue
        codes, rest = line.split(";", 1)
        if not rest.strip().startswith("fully-qualified"):
            continue
        emoji = "".join(chr(int(code, 16)) for code in codes.split())
        if SKIN_TONES.intersection(emoji):
            continue
        current["emojis"].append(emoji)

    unknown = set(GROUPS.values()) - {group["id"] for group in groups}
    if unknown:
        raise SystemExit(f"emoji-test.txt no tiene los grupos {sorted(unknown)}: ¿ha cambiado el formato?")
    return groups


def load_annotations(cldr_language):
    annotations = {}
    for package, key in (("cldr-annotations-full/annotations", "annotations"),
                         ("cldr-annotations-derived-full/annotationsDerived", "annotationsDerived")):
        data = json.loads(fetch(f"{CLDR_BASE_URL}/{package}/{cldr_language}/annotations.json"))
        annotations.update(data[key]["annotations"])
    return annotations


def annotation(annotations, emoji):
    # CLDR quita el selector de variación FE0F de sus claves.
    return annotations.get(emoji) or annotations.get(emoji.replace(VARIATION_SELECTOR, ""))


def main():
    groups = parse_emoji_test(fetch(EMOJI_TEST_URL))
    annotations = {language: load_annotations(cldr) for language, cldr in LANGUAGES.items()}

    catalog = {"emojiVersion": EMOJI_VERSION, "cldrVersion": CLDR_VERSION, "groups": []}
    missing = []
    for group in groups:
        entries = []
        for emoji in group["emojis"]:
            names, keywords = {}, {}
            for language in LANGUAGES:
                found = annotation(annotations[language], emoji)
                if found is None:
                    missing.append((language, emoji))
                    continue
                name = found["tts"][0]
                names[language] = name
                # El nombre ya se busca: solo las palabras que añaden algo.
                extra = [word for word in found.get("default", []) if word.lower() != name.lower()]
                if extra:
                    keywords[language] = " ".join(extra)
            entry = {"e": emoji, "n": names}
            if keywords:
                entry["k"] = keywords
            entries.append(entry)
        catalog["groups"].append({"id": group["id"], "emojis": entries})

    if missing:
        raise SystemExit(f"Faltan {len(missing)} nombres en CLDR, p. ej. {missing[:5]}: revisa CLDR_VERSION")

    OUTPUT.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    count = sum(len(group["emojis"]) for group in catalog["groups"])
    print(f"{count} emojis en {len(catalog['groups'])} grupos → {OUTPUT} ({OUTPUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
