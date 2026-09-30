# Pinned tool versions

| Tool | Version | Notes |
|---|---|---|
| Godot | **4.7.2-stable** (standard, not .NET) | Latest stable at project start. Upgrade only between milestones, followed by a full determinism run. |
| GUT | **9.7.0** | Included in `addons/gut` (MIT). Built for Godot 4.7 type checking. |
| Blender | **5.2.2 LTS** | Used headless by the `blender-lowpoly-assets` skill. |

Verified on 30 Sep 2026: the four sample .glb files import into Godot 4.7.2 with hardpoints, markers, LODs and material names intact, and the placeholder GUT test passes headless.
