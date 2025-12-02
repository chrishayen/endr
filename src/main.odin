package endr

import "core:os"
import "core:fmt"
import "core:strings"
import "core:path/filepath"

VERSION :: "0.1.0"

main :: proc() {
    args := os.args[1:]

    if len(args) == 0 {
        print_usage()
        return
    }

    command := args[0]
    rest := args[1:] if len(args) > 1 else []string{}

    switch command {
    case "init":
        cmd_init(rest)
    case "add":
        cmd_add(rest)
    case "remove", "rm":
        cmd_remove(rest)
    case "install", "i":
        cmd_install(rest)
    case "build", "b":
        cmd_build(rest)
    case "run", "r":
        cmd_run(rest)
    case "flags":
        cmd_flags(rest)
    case "ols":
        cmd_ols(rest)
    case "help", "-h", "--help":
        print_usage()
    case "version", "-v", "--version":
        fmt.printf("endr version %s\n", VERSION)
    case:
        fmt.eprintf("Unknown command: %s\n", command)
        print_usage()
        os.exit(1)
    }
}

print_usage :: proc() {
    fmt.print(`endr - Odin Package Manager

Usage: endr <command> [arguments]

Commands:
    init                 Create a new endr.toml in the current directory
    add <url> [options]  Add a dependency
    remove <name>        Remove a dependency
    install              Install all dependencies
    build [args...]      Build with odin, injecting collection flags
    run [args...]        Run with odin, injecting collection flags
    flags                Print the collection flags for manual use
    ols                  Generate ols.json for editor/LSP support
    help                 Show this help message
    version              Show version

Add Options:
    --name <name>        Name for the dependency (default: repo name)
    --branch <branch>    Clone specific branch
    --tag <tag>          Clone specific tag

Examples:
    endr init
    endr add https://github.com/Up05/toml_parser
    endr add https://github.com/user/lib --name mylib --branch main
    endr install
    endr build .
    endr run . -debug
`)
}

cmd_init :: proc(args: []string) {
    if os.exists(MANIFEST_FILE) {
        fmt.eprintln("Error:", MANIFEST_FILE, "already exists")
        os.exit(1)
    }

    // Get project name from current directory
    cwd := os.get_current_directory()
    name := filepath.base(cwd)

    if !create_default_manifest(name) {
        fmt.eprintln("Error: Could not create", MANIFEST_FILE)
        os.exit(1)
    }

    // Create .endr directory
    if !os.exists(".endr") {
        os.make_directory(".endr")
    }

    fmt.println("Created", MANIFEST_FILE)
}

cmd_add :: proc(args: []string) {
    if len(args) == 0 {
        fmt.eprintln("Error: URL required")
        fmt.eprintln("Usage: endr add <url> [--name <name>] [--branch <branch>] [--tag <tag>]")
        os.exit(1)
    }

    url := args[0]
    name: string
    branch: Maybe(string)
    tag: Maybe(string)

    // Parse options
    i := 1
    for i < len(args) {
        if args[i] == "--name" && i + 1 < len(args) {
            name = args[i + 1]
            i += 2
        } else if args[i] == "--branch" && i + 1 < len(args) {
            branch = args[i + 1]
            i += 2
        } else if args[i] == "--tag" && i + 1 < len(args) {
            tag = args[i + 1]
            i += 2
        } else {
            fmt.eprintf("Unknown option: %s\n", args[i])
            os.exit(1)
        }
    }

    // Default name from URL
    if name == "" {
        name = extract_repo_name(url)
    }

    if name == "" {
        fmt.eprintln("Error: Could not determine package name from URL")
        fmt.eprintln("Use --name to specify a name")
        os.exit(1)
    }

    // Check if manifest exists
    if !os.exists(MANIFEST_FILE) {
        fmt.eprintln("Error:", MANIFEST_FILE, "not found. Run 'endr init' first")
        os.exit(1)
    }

    if !manifest_add_dependency(name, url, branch, tag) {
        fmt.eprintln("Error: Could not add dependency")
        os.exit(1)
    }

    fmt.printf("Added %s\n", name)
}

cmd_remove :: proc(args: []string) {
    if len(args) == 0 {
        fmt.eprintln("Error: Package name required")
        fmt.eprintln("Usage: endr remove <name>")
        os.exit(1)
    }

    name := args[0]

    if !os.exists(MANIFEST_FILE) {
        fmt.eprintln("Error:", MANIFEST_FILE, "not found")
        os.exit(1)
    }

    if !manifest_remove_dependency(name) {
        fmt.eprintln("Error: Could not remove dependency")
        os.exit(1)
    }

    // Also remove the package directory
    pkg_path := filepath.join({PACKAGES_DIR, name}, context.temp_allocator)
    if os.exists(pkg_path) {
        remove_directory(pkg_path)
    }

    fmt.printf("Removed %s\n", name)
}

cmd_install :: proc(args: []string) {
    if !os.exists(MANIFEST_FILE) {
        fmt.eprintln("Error:", MANIFEST_FILE, "not found. Run 'endr init' first")
        os.exit(1)
    }

    if !install_dependencies() {
        fmt.eprintln("Some dependencies failed to install")
        os.exit(1)
    }

    fmt.println("All dependencies installed")
}

cmd_build :: proc(args: []string) {
    if !build_project(args) {
        os.exit(1)
    }
}

cmd_run :: proc(args: []string) {
    if !run_project(args) {
        os.exit(1)
    }
}

cmd_flags :: proc(args: []string) {
    flags := get_collection_flags(context.temp_allocator)
    if flags != "" {
        fmt.println(flags)
    }
}

cmd_ols :: proc(args: []string) {
    if !generate_ols_config() {
        fmt.eprintln("Error: Could not generate", OLS_FILE)
        os.exit(1)
    }
    fmt.println("Generated", OLS_FILE)
}

// Extract repository name from URL
extract_repo_name :: proc(url: string) -> string {
    // Remove trailing .git
    url := url
    url = strings.trim_suffix(url, ".git")

    // Get the last path component
    parts := strings.split(url, "/", allocator = context.temp_allocator)
    if len(parts) > 0 {
        return parts[len(parts) - 1]
    }

    return ""
}
