# vstools.nvim

A Neovim plugin that brings essential **Visual Studio workflow
features** into Neovim for C/C++ projects using MSVC.

Features include:

✅ Select a **startup project** (`.vcxproj`)\
✅ Per-workspace **Debug/Release** build configuration\
✅ Per-startup-project **run arguments** (structured)\
✅ Per-project **environment variables** (future-proof)\
✅ Build project or solution using `msbuild.exe`\
✅ Clean project or solution\
✅ Run the startup executable\
✅ Reliable **Build → Run** chain using async job execution\
✅ Integration with **floating_terminal.nvim**\
✅ Telescope picker integration

------------------------------------------------------------------------

## ✨ Features

### Startup Project Selection

Choose a startup `.vcxproj` using a Telescope picker.\
Persisted per workspace.

### Build Configuration

Switch between:

-   `Debug`
-   `Release`

Persisted per workspace.

### Build Actions

-   Build startup project
-   Build full solution
-   Clean project
-   Clean solution

Defaults to use `msbuild.exe` with fully async execution via `vim.system`.

### Run Actions

-   Automatically detects the executable output directory:

        x64/Debug/*.exe
        x64/Release/*.exe
        Debug/*.exe
        Release/*.exe

-   Runs the executable with configured run arguments.

### Build → Run

A correct, async-safe pipeline:

-   Build runs default via `vim.system`
-   If ran interactively then eeverything goes to `floating_terminal.nvim`

### Run Arguments (per startup project)

Define arguments in a dedicated scratch buffer:

    -data a b
    --mode fast
    --flag

Internally stored as structured groups:

``` json
[
  ["-data", "a", "b"],
  ["--mode", "fast"],
  ["--flag"]
]
```

------------------------------------------------------------------------

## 📦 Installation

Using **lazy.nvim**:

``` lua
{
  "carldersell/vstools.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "carldersell/floating_terminal.nvim",
  },
  config = function()
    require("vstools").setup()
  end,
}
```

------------------------------------------------------------------------

## 🔧 Configuration

Default setup:

``` lua
require("vstools").setup({
  -- Path to msbuild.exe
  msbuild_path = "msbuild.exe",

  -- Optional prefix before executable path (useful for nushell)
  prepend_exe_path = "",

  build_config = "Debug",

  log_settings = {
    width = 0.8,
    height = 0.8,
    border = "rounded"
  },
})
```

------------------------------------------------------------------------

## 🧠 State Storage

State is saved at:

    stdpath("data")/vstools/state.json

Structure:

``` json
{
  "C:/my/workspace": {
    "build_config": "Debug",
    "current_startup_project": "src/app/app.vcxproj",
    "startup_projects": {
      "src/app/app.vcxproj": {
        "run_args": [
          ["-data", "a", "b"],
          ["--mode", "fast"]
        ],
        "environment": {
          "VAR": "VALUE"
        }
      }
    }
  }
}
```

This allows:

-   workspace-wide settings\
-   per-startup-project settings

------------------------------------------------------------------------

## 🛠 Commands

### Startup Project

    :VSSelectStartupProject     -- choose a .vcxproj
    :VSShowStartupProject       -- show current project

### Build Config

    :VSSetBuildConfig Debug|Release
    :VSBuildConfigToggle

### Build / Clean

    :VSBuildProject
    :VSBuildSolution
    :VSCleanProject
    :VSCleanSolution

### Run / Build+Run

    :VSRunProject
    :VSBuildAndRun

### Edit Run Arguments

    :VSEditRunArgs

Opens a scratch buffer whose content becomes grouped argument
structure.\
Save with `:w`.

------------------------------------------------------------------------

## 🎯 Run Arguments Format

Each **line = one argument group**, e.g.:

    -data a b c
    --flag
    --path "folder with spaces"

Stored as:

``` json
[
  ["-data", "a", "b", "c"],
  ["--flag"],
  ["--path", "folder with spaces"]
]
```

Automatically used when launching the executable.

------------------------------------------------------------------------

## ✅ Requirements

-   Windows\
-   Neovim **0.10+** (for `vim.system`)\
-   Telescope\
-   floating_terminal.nvim

------------------------------------------------------------------------

## 🚀 Example Workflow

1.  `:VSSelectStartupProject`\
2.  `:VSSetBuildConfig Release`\
3.  `:VSEditRunArgs`\
4.  `:VSBuildAndRun`

------------------------------------------------------------------------

## 📄 License

MIT
