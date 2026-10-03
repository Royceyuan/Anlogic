"""Assemble the PC-only offline delivery; never include FPGA/TF/user media."""

import argparse
import hashlib
import json
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

from PyInstaller.depend.bindepend import get_imports

from align_worker import MODEL_SHA256


HERE = Path(__file__).resolve().parent
MODEL_URL = f"https://openaipublic.azureedge.net/main/whisper/models/{MODEL_SHA256}/small.pt"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", type=Path, required=True, help="Conda ffmpeg.exe; dependency licenses/recipes must be available")
    args = parser.parse_args()
    worker = HERE / "AlignmentWorker" / "AlignmentWorker.exe"
    if not worker.is_file():
        raise FileNotFoundError("Build AlignmentWorker before assembling the offline bundle")
    model = HERE / "models" / "small.pt"
    model.parent.mkdir(exist_ok=True)
    if not model.is_file():
        temporary = model.with_suffix(".download")
        urllib.request.urlretrieve(MODEL_URL, temporary)
        if digest(temporary) != MODEL_SHA256:
            raise ValueError("Downloaded model checksum mismatch")
        temporary.replace(model)
    if digest(model) != MODEL_SHA256:
        raise ValueError("Local model checksum mismatch")
    media_bin = args.ffmpeg.resolve().parent
    conda_root = media_bin.parent.parent
    dlls = set()
    queue = [args.ffmpeg.resolve(), media_bin / "ffprobe.exe"]
    while queue:
        path = queue.pop()
        if path in dlls:
            continue
        dlls.add(path)
        for name, resolved in get_imports(str(path), search_paths=[str(media_bin)]):
            if resolved and Path(resolved).is_relative_to(media_bin):
                queue.append(Path(resolved))
            elif resolved is None and not name.lower().startswith(("api-ms-", "ext-ms-")):
                raise FileNotFoundError(f"Unresolved dependency {name} in {path}")
    destination = HERE / "ffmpeg"
    destination.mkdir(exist_ok=True)
    for path in dlls:
        shutil.copy2(path, destination / path.name)

    licenses = HERE / "offline_licenses"
    licenses.mkdir(exist_ok=True)
    packages = []
    native_files = {path.relative_to(conda_root).as_posix().lower() for path in dlls}
    for metadata in (conda_root / "conda-meta").glob("*.json"):
        entry = json.loads(metadata.read_text(encoding="utf-8"))
        if not native_files.intersection(path.lower() for path in entry.get("files", [])):
            continue
        cache = Path(entry["link"]["source"]) / "info"
        target = licenses / metadata.stem
        target.mkdir(exist_ok=True)
        shutil.copy2(metadata, target / "conda-package.json")
        for folder in ("licenses", "recipe"):
            if (cache / folder).is_dir():
                shutil.copytree(cache / folder, target / folder, dirs_exist_ok=True)
        packages.append({"name": entry["name"], "version": entry["version"],
                         "license": entry.get("license"), "url": entry.get("url"),
                         "recipe": f"offline_licenses/{metadata.stem}/recipe"})
    # Preserve license files and metadata for every installed worker dependency.
    for site in (HERE / "_alignment_runtime/Lib/site-packages", Path(sys.prefix) / "Lib/site-packages"):
        for metadata in site.glob("*.dist-info"):
            target = licenses / metadata.name
            target.mkdir(exist_ok=True)
            for path in metadata.rglob("*"):
                if path.is_file() and (path.name in ("METADATA", "COPYING") or "license" in path.name.lower()):
                    relative = path.relative_to(metadata)
                    (target / relative).parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target / relative)
    for source, name in ((Path(sys.base_prefix) / "LICENSE.txt", "Python_GUI_LICENSE.txt"),
                         (Path(r"D:\Anaconda\envs\Deep_Learning\LICENSE_PYTHON.txt"), "Python_Worker_LICENSE.txt")):
        if source.is_file():
            shutil.copy2(source, licenses / name)
    for source in (Path(sys.base_prefix) / "tcl").glob("*/license.terms"):
        shutil.copy2(source, licenses / f"{source.parent.name}_license.terms")
    (licenses / "native_components.json").write_text(json.dumps(packages, indent=2), encoding="utf-8")

    included = [HERE / name for name in ("MuseumTFPackager.exe", "MuseumTFPackager.exe.sha256", "README.md", "VALIDATION.md",
                                         "THIRD_PARTY_NOTICES.md", "AlignmentWorker", "models", "ffmpeg", "offline_licenses")]
    paths = sorted(path for item in included for path in (item.rglob("*") if item.is_dir() else [item]) if path.is_file())
    manifest = {path.relative_to(HERE).as_posix(): {"bytes": path.stat().st_size, "sha256": digest(path)} for path in paths}
    (HERE / "offline_bundle_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    archive = HERE / "MuseumTFPackager_Offline.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as output:
        for path in paths + [HERE / "offline_bundle_manifest.json"]:
            output.write(path, "MuseumTFPackager/" + path.relative_to(HERE).as_posix())
    print(f"PASS offline bundle: {len(paths)} files, {archive.stat().st_size} bytes, SHA256 {digest(archive)}")


if __name__ == "__main__":
    main()
