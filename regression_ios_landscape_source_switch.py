from pathlib import Path

root = Path(__file__).resolve().parent
player = (root / "GhostStream/Views/PlayerView.swift").read_text()
launcher = (root / "GhostStream/Views/LauncherView.swift").read_text()

start = launcher.index("private struct SavedSourcesView")
end = launcher.index("private func kindLabel", start)
saved = launcher[start:end]
load_pos = saved.find("await library.load(source: source)")
activate_pos = saved.find("store.setActive(source)")
validate_pos = saved.find("guard library.loadedSourceID == source.id")

checks = {
    "native video keeps VOD fill and Live fit": "parent.kind == .live ? .resizeAspect : .resizeAspectFill" in player,
    "native player clips filled video": "view.clipsToBounds = true" in player,
    "saved source loads before activation": 0 <= load_pos < activate_pos,
    "saved source validates load before activation": 0 <= validate_pos < activate_pos,
    "old EPG cleared before switching": 0 <= saved.find("epg.clear()") < load_pos,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL"), name)
if failed:
    raise SystemExit("FAILED: " + ", ".join(failed))
