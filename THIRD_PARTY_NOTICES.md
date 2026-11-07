# Third-party components

Own code, documentation and the procedural primitive scene in this repository are covered by [LICENSE](LICENSE), MIT. No external art, fonts, audio, plugins or Steam SDK are included.

| Component | Version / source | License / notices | Use |
| --- | --- | --- | --- |
| Godot Engine Standard | 4.7.2-stable, official build `ed1daf0bf`; [release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) | MIT plus upstream component licenses | Editor, runtime and export templates |
| Jolt Physics | Version embedded by the pinned Godot build; [upstream](https://github.com/jrouwe/JoltPhysics), [Godot module](https://github.com/godotengine/godot/tree/4.7.2-stable/modules/jolt_physics) | MIT; see Godot copyright metadata and bundled texts | Built-in 3D simulation; no separate extension |
| actions/checkout | v7.0.1, commit `3d3c42e5aac5ba805825da76410c181273ba90b1`; [source](https://github.com/actions/checkout/tree/3d3c42e5aac5ba805825da76410c181273ba90b1) | MIT | CI only; not shipped with the game |

The pinned engine reports its bundled dependencies and their exact copyright notices. They are preserved in:

- [Godot MIT text](content/licenses/GODOT_LICENSE.txt).
- [Upstream component copyright metadata](content/licenses/GODOT_COPYRIGHT.json).
- [Full third-party license texts](content/licenses/GODOT_THIRD_PARTY.txt).

Regenerate these files with the pinned editor and `--headless --path . --script tools/generate_notices.gd` when the engine changes. The raw notice metadata is copied without relabeling its components as project MIT. Preserve `content/licenses/` beside distributed binaries; `tools/export.ps1` creates that layout and export presets also include them in the package. Export templates come from the same verified upstream release as the editor; archive checksums are locked in the repository's [tools/toolchain.json](https://github.com/hhypest/project-evacuation/blob/main/tools/toolchain.json).

Packaging and platform verification are separate. Steamworks, if introduced later, requires its own entry and distribution review.
