import hashlib
import io
import os
import shutil
import tarfile
import time

ROOT = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.join(ROOT, "docs")
os.makedirs(DOCS, exist_ok=True)

DYLIB = os.path.join(ROOT, "libSakuraIcons.dylib")
PLIST = os.path.join(ROOT, "SakuraIcons.plist")

VERSION = "0.11.0"
TWEAK_DIR = "var/jb/Library/MobileSubstrate/DynamicLibraries"

PRESETS = {
    "ice": ("Ice", "#0A1F3C", "#5AA9FF"),
    "sakura": ("Sakura", "#3A1230", "#FF8FC7"),
    "mono": ("Mono", "#121212", "#BDBDBD"),
    "midnight": ("Midnight", "#05070D", "#3D5AFE"),
}

BASE_PREFS = {
    "enabled": True,
    "hideLabels": True,
    "tint": True,
    "border": True,
    "cardAlpha": 0.72,
    "tintAlpha": 0.45,
    "cardRadius": 0.24,
    "grow": 0.07,
}

PREFS_DIR = "var/mobile/Library/Preferences"


def entry(tar, name, data, mode, isdir=False):
    ti = tarfile.TarInfo(name)
    ti.mode = mode
    ti.mtime = int(time.time())
    ti.uid = 0
    ti.gid = 0
    ti.uname = "root"
    ti.gname = "wheel"
    if isdir:
        ti.type = tarfile.DIRTYPE
        tar.addfile(ti)
    else:
        ti.size = len(data)
        tar.addfile(ti, io.BytesIO(data))


def targz(files, dirs):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz", format=tarfile.GNU_FORMAT) as tar:
        for d in dirs:
            entry(tar, d.rstrip("/") + "/", b"", 0o755, isdir=True)
        for name, data, mode in files:
            entry(tar, name, data, mode)
    return buf.getvalue()


def ar(name, data):
    h = "%-16s%-12s%-6s%-6s%-8s%-10s`\n" % (name, 0, 0, 0, 100644, len(data))
    out = h.encode() + data
    return out + (b"\n" if len(data) % 2 else b"")


def build_deb(path, control, files, dirs):
    with open(path, "wb") as f:
        f.write(b"!<arch>\n")
        f.write(ar("debian-binary", b"2.0\n"))
        f.write(ar("control.tar.gz", targz([("./control", control.encode(), 0o644)], [])))
        f.write(ar("data.tar.gz", targz(files, dirs)))
    return path


def plist_xml(prefs):
    def v(x):
        if isinstance(x, bool):
            return "<true/>" if x else "<false/>"
        if isinstance(x, (int, float)):
            return "<real>%s</real>" % x
        return "<string>%s</string>" % x

    items = "".join("<key>%s</key>%s" % (k, v(val)) for k, val in prefs.items())
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0"><dict>%s</dict></plist>\n' % items
    ).encode()


def deb_record(path, package, version, architecture, description, depends="", conflicts=""):
    data = open(path, "rb").read()
    lines = [
        "Package: %s" % package,
        "Version: %s" % version,
        "Architecture: %s" % architecture,
        "Section: Tweaks",
        "Maintainer: sonekk",
        "Author: sonekk",
        "Description: %s" % description,
        "Filename: ./%s" % os.path.basename(path),
        "Size: %d" % len(data),
        "MD5sum: %s" % hashlib.md5(data).hexdigest(),
        "SHA256: %s" % hashlib.sha256(data).hexdigest(),
    ]
    if depends:
        lines.append("Depends: %s" % depends)
    if conflicts:
        lines.append("Conflicts: %s" % conflicts)
    return "\n".join(lines) + "\n"


def main():
    dylib = open(DYLIB, "rb").read()
    plist = open(PLIST, "rb").read()

    control = (
        "Package: com.sonekk.sakuraicons\n"
        "Name: SakuraIcons\n"
        "Version: %s\n"
        "Architecture: iphoneos-arm64e\n"
        "Description: Tinted blue icons on dark cards with hidden labels.\n"
        "Maintainer: sonekk\n"
        "Author: sonekk\n"
        "Section: Tweaks\n" % VERSION
    )

    files = [
        (TWEAK_DIR + "/SakuraIcons.dylib", dylib, 0o755),
        (TWEAK_DIR + "/SakuraIcons.plist", plist, 0o644),
    ]

    tweak = build_deb(
        os.path.join(DOCS, "SakuraIcons_%s_arm64e.deb" % VERSION),
        control,
        files,
        [TWEAK_DIR],
    )
    shutil.copyfile(tweak, os.path.join(DOCS, "SakuraIcons.deb"))

    records = [
        deb_record(tweak, "com.sonekk.sakuraicons", VERSION, "iphoneos-arm64e",
                   "Tinted blue icons on dark cards with hidden labels.")
    ]

    for key, (name, card, tint) in PRESETS.items():
        prefs = dict(BASE_PREFS)
        prefs["cardColor"] = card
        prefs["tintColor"] = tint

        conflicts = ",".join(
            "com.sonekk.sakuraicons.preset-" + k for k in PRESETS if k != key
        )
        control = (
            "Package: com.sonekk.sakuraicons.preset-%s\n"
            "Name: SakuraIcons Preset: %s\n"
            "Version: 1.0.2\n"
            "Architecture: all\n"
            "Description: Applies the %s palette to SakuraIcons.\n"
            "Maintainer: sonekk\n"
            "Author: sonekk\n"
            "Section: Tweaks\n"
            "Depends: com.sonekk.sakuraicons\n"
            "Conflicts: %s\n" % (key, name, name, conflicts)
        )

        path = build_deb(
            os.path.join(DOCS, "SakuraIconsPreset_%s_1.0.2_all.deb" % key),
            control,
            [(PREFS_DIR + "/com.sonekk.sakuraicons.plist", plist_xml(prefs), 0o644)],
            [PREFS_DIR],
        )
        records.append(
            deb_record(path, "com.sonekk.sakuraicons.preset-" + key, "1.0.2", "all",
                       "Applies the %s palette to SakuraIcons." % name,
                       depends="com.sonekk.sakuraicons", conflicts=conflicts)
        )

    with open(os.path.join(DOCS, "Packages"), "w", encoding="utf-8") as f:
        f.write("\n".join(records))

    with open(os.path.join(DOCS, "Release"), "w", encoding="utf-8") as f:
        f.write("Origin: sonekk\nLabel: SONEKK\nSuite: stable\nVersion: 1.0\n"
                "Codename: ios\nArchitectures: iphoneos-arm64e all\n"
                "Components: main\nDescription: SakuraIcons tweak and presets\n")

    keep = {"Packages", "Release", "SakuraIcons.deb"}
    for name in os.listdir(DOCS):
        if name.endswith(".deb") and name not in keep and VERSION not in name and "1.0.2" not in name:
            os.remove(os.path.join(DOCS, name))

    print("repo:", VERSION)
    for name in sorted(os.listdir(DOCS)):
        print(" ", name, os.path.getsize(os.path.join(DOCS, name)), "B")


if __name__ == "__main__":
    main()
