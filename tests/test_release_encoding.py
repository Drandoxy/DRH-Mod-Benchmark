"""Audit every tracked text file and an optional launcher ZIP/JSON pair."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def text_audit(raw, name):
    text = raw.decode("utf-8-sig")
    assert text.isascii(), "Non-ASCII text: " + name
    assert all(ord(c) >= 32 or c in "\n\r\t" for c in text), name
    if name.endswith(".json"):
        assert json.dumps(json.loads(text), ensure_ascii=False).isascii(), name
    return text

files = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
BINARY = (".png",)
for name in filter(None, files):
    if name.endswith(BINARY):
        continue
    text_audit((ROOT / name).read_bytes(), name)

if len(sys.argv) == 3:
    archive_path, entry_path = map(Path, sys.argv[1:])
    entry = json.loads(text_audit(entry_path.read_bytes(), entry_path.name))
    raw = archive_path.read_bytes()
    assert entry["size"] == len(raw)
    assert entry["sha256"] == hashlib.sha256(raw).hexdigest()
    with zipfile.ZipFile(archive_path) as archive:
        assert archive.testzip() is None
        names = archive.namelist()
        expected = {"mod.json", "README.md", "LICENSE"}
        for folder in ("src", "Resources"):
            expected.update(p.relative_to(ROOT).as_posix() for p in (ROOT / folder).rglob("*") if p.is_file())
        assert set(names) == expected and len(names) == len(expected)
        for name in names:
            member = archive.read(name)
            assert member == (ROOT / name).read_bytes(), "Source/ZIP mismatch: " + name
            text_audit(member, name)
        manifest = json.loads(archive.read("mod.json"))
        for key in ("id", "name", "version", "author", "description", "api", "drh", "uses"):
            assert entry[key] == manifest[key], key
        readme = archive.read("README.md").decode("utf-8")
        shown = readme.split("<!-- drh:show -->")[1].split("<!-- /drh:show -->")[0].strip()
        assert entry["longDescription"] == shown and len(shown) <= 4000
        source = "https://github.com/Drandoxy/DRH-Mod-Benchmark"
        assert entry["source"] == source
        assert entry["url"] == source + "/releases/download/v" + manifest["version"] + "/" + archive_path.name
print("PASS: tracked text encoding and punctuation audit" + ("; ZIP/source/entry integrity" if len(sys.argv) == 3 else ""))
