# Agent Guidelines for RC Vibe GP

## 1. Scratch Folder Preservation (CRITICAL)
- The `scratch/` folder contains permanent test scripts, probes, look-dev tools, and validation scenes.
- **NEVER** add `scratch/` to `.gitignore`.
- **NEVER** delete or remove files in `scratch/`. All scratch scripts are kept for future testing, regression checks, and debugging.
- When creating new test scripts or inspection probes, place them in `scratch/` and leave them there.

## 2. Level Generation Architecture
- Levels (`levels/*Level.tscn`) and generated meshes (`generated/*.res`) are written by generator scripts (`regenerate_<level>.gd`).
- Do not hand-edit level geometry or dressing directly in generated files without also updating the corresponding generator script.
- See `CLAUDE.md` for full project architecture and generator details.
