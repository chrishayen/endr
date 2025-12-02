# Endr

A lightweight package manager for the [Odin programming language](https://odin-lang.org/).

## Features

- Add packages from Git repositories with support for branches, tags, and commits
- Lock file tracking for reproducible builds
- Seamless integration with `odin build` and `odin run`
- Editor/LSP support via automatic `ols.json` generation
- Native library support with pre-build hooks and linker flag injection
- Simple TOML-based configuration

## Installation

Requires: Odin compiler, Git, Make

```bash
git clone https://github.com/chrishayen/endr.git
cd endr
make install
```

This installs `endr` to `~/.local/bin/`. Ensure this directory is in your PATH.

## Quick Start

```bash
# Initialize a new project
endr init

# Add a dependency
endr add https://github.com/Up05/toml_parser

# Install all dependencies
endr install

# Build your project
endr build .
```

## Commands

### `endr init`

Creates a new `endr.toml` manifest file in the current directory.

### `endr add <url>`

Add a Git repository as a dependency.

Options:
- `--name <name>` - Custom package name (defaults to repository name)
- `--branch <branch>` - Clone a specific branch
- `--tag <tag>` - Clone a specific tag

Examples:
```bash
endr add https://github.com/user/library
endr add https://github.com/user/library --name mylib
endr add https://github.com/user/library --branch develop
endr add https://github.com/user/library --tag v1.0.0
```

### `endr remove <name>`

Remove a dependency from the project.

```bash
endr remove mylib
```

### `endr install`

Install all dependencies listed in `endr.toml`. Packages are cloned to `.endr/packages/`.

### `endr update [name]`

Update packages to their latest versions. Without arguments, updates all packages. Specify a package name to update only that package.

```bash
# Update all packages
endr update

# Update a specific package
endr update toml_parser
```

### `endr build [args...]`

Build the project with Odin, automatically injecting collection flags for dependencies.

```bash
endr build .
endr build . -debug
endr build . -o:speed
```

### `endr run [args...]`

Run the project with Odin, injecting collection flags.

```bash
endr run .
endr run . -debug
```

### `endr flags`

Display the collection flags for manual use with the Odin compiler.

```bash
odin build . $(endr flags)
```

### `endr ols`

Generate an `ols.json` configuration file for editor/LSP support. This enables editors like Helix, VS Code, and others using [OLS (Odin Language Server)](https://github.com/DanielGavin/ols) to provide symbol information, hover docs, and completions for installed packages.

```bash
endr ols
```

The generated config includes the `deps` collection pointing to `.endr/packages/`. If `ODIN_ROOT` is set, it also includes the `core` and `vendor` collections.

Note: `ols.json` is automatically regenerated when running `endr install`.

### `endr version`

Display version information.

### `endr help`

Display help message.

## Configuration

### endr.toml

The manifest file defines your project and its dependencies.

```toml
[package]
name = "myproject"
version = "0.1.0"

[dependencies]
# Simple form - just the URL
toml_parser = "https://github.com/Up05/toml_parser"

# Extended form - with branch or tag
mylib = { url = "https://github.com/user/lib", branch = "main" }
otherlib = { url = "https://github.com/user/other", tag = "v2.0.0" }

[build]
# Optional: run a script before building (e.g., compile C code)
pre_build = "./build_libs.sh"

[native_libs]
# Optional: link native libraries
path = "build/lib"           # directory containing .so/.dylib files
libs = ["clarity", "face"]   # libraries to link (-lclarity -lface)
```

### Native Library Integration

If your project includes C code that needs to be compiled and linked, you can use `pre_build` and `native_libs`:

1. Create a build script (e.g., `build_libs.sh`) that compiles your C code:
```bash
#!/bin/bash
mkdir -p build/lib
gcc -shared -fPIC -o build/lib/libmylib.so src/mylib.c $(pkg-config --cflags --libs somedep)
```

2. Configure `endr.toml`:
```toml
[build]
pre_build = "./build_libs.sh"

[native_libs]
path = "build/lib"
libs = ["mylib"]
```

3. Build with `endr build .` - the pre_build script runs first, then odin compiles with the linker flags.

### endr.lock

The lock file is automatically generated and tracks the exact commits of installed packages. Commit this file to version control for reproducible builds.

```toml
[packages]
toml_parser = { url = "https://github.com/Up05/toml_parser", commit = "abc123..." }
```

## Using Dependencies

After installation, import packages using the `deps` collection:

```odin
import toml "deps:toml_parser"

main :: proc() {
    // Use the package
}
```

## Directory Structure

```
your-project/
  endr.toml        # Project manifest
  endr.lock        # Lock file (auto-generated)
  ols.json         # Editor/LSP config (auto-generated)
  .endr/
    packages/      # Installed dependencies
  src/
    main.odin
```

## License

MIT
