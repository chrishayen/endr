package endr

import "core:os"
import "core:strings"
import "core:fmt"
import toml "deps:toml"

Build :: struct {
    pre_build: Maybe(string),
}

NativeLibs :: struct {
    path: string,
    libs: [dynamic]string,
}

Manifest :: struct {
    name:         string,
    version:      string,
    dependencies: map[string]Dependency,
    build:        Build,
    native_libs:  Maybe(NativeLibs),
}

Dependency :: struct {
    url:    string,
    branch: Maybe(string),
    tag:    Maybe(string),
    commit: Maybe(string),
}

LockEntry :: struct {
    url:    string,
    commit: string,
}

LockFile :: struct {
    packages: map[string]LockEntry,
}

MANIFEST_FILE :: "endr.toml"
LOCK_FILE :: "endr.lock"
PACKAGES_DIR :: ".endr/packages"

load_manifest :: proc(allocator := context.allocator) -> (manifest: Manifest, ok: bool) {
    context.allocator = allocator

    root, err := toml.parse_file(MANIFEST_FILE, allocator)
    if err.type != .None {
        toml.print_error(err)
        return manifest, false
    }
    defer toml.deep_delete(root, allocator)

    // Parse [package] section
    pkg_table, pkg_ok := toml.get_table(root, "package")
    if pkg_ok {
        manifest.name, _ = toml.get_string(pkg_table, "name")
        manifest.version, _ = toml.get_string(pkg_table, "version")
        // Clone strings since we're freeing the toml data
        manifest.name = strings.clone(manifest.name, allocator)
        manifest.version = strings.clone(manifest.version, allocator)
    }

    // Parse [dependencies] section
    deps_table, deps_ok := toml.get_table(root, "dependencies")
    if deps_ok {
        manifest.dependencies = make(map[string]Dependency, allocator = allocator)
        for name, value in deps_table {
            dep: Dependency
            #partial switch v in value {
            case string:
                // Simple form: name = "url"
                dep.url = strings.clone(v, allocator)
            case ^toml.Table:
                // Extended form: name = { url = "...", branch = "..." }
                url_str, url_ok := toml.get_string(v, "url")
                if url_ok {
                    dep.url = strings.clone(url_str, allocator)
                }
                branch_str, branch_ok := toml.get_string(v, "branch")
                if branch_ok {
                    dep.branch = strings.clone(branch_str, allocator)
                }
                tag_str, tag_ok := toml.get_string(v, "tag")
                if tag_ok {
                    dep.tag = strings.clone(tag_str, allocator)
                }
                commit_str, commit_ok := toml.get_string(v, "commit")
                if commit_ok {
                    dep.commit = strings.clone(commit_str, allocator)
                }
            }
            manifest.dependencies[strings.clone(name, allocator)] = dep
        }
    }

    // Parse [build] section
    build_table, build_ok := toml.get_table(root, "build")
    if build_ok {
        pre_build_str, pre_ok := toml.get_string(build_table, "pre_build")
        if pre_ok {
            manifest.build.pre_build = strings.clone(pre_build_str, allocator)
        }
    }

    // Parse [native_libs] section
    native_table, native_ok := toml.get_table(root, "native_libs")
    if native_ok {
        native: NativeLibs
        path_str, path_ok := toml.get_string(native_table, "path")
        if path_ok {
            native.path = strings.clone(path_str, allocator)
        }
        libs_list, libs_ok := toml.get_list(native_table, "libs")
        if libs_ok && libs_list != nil {
            native.libs = make([dynamic]string, allocator = allocator)
            for item in libs_list {
                #partial switch v in item {
                case string:
                    append(&native.libs, strings.clone(v, allocator))
                }
            }
        }
        manifest.native_libs = native
    }

    return manifest, true
}

load_lock_file :: proc(allocator := context.allocator) -> (lock: LockFile, ok: bool) {
    context.allocator = allocator

    if !os.exists(LOCK_FILE) {
        lock.packages = make(map[string]LockEntry, allocator = allocator)
        return lock, true
    }

    root, err := toml.parse_file(LOCK_FILE, allocator)
    if err.type != .None {
        toml.print_error(err)
        return lock, false
    }
    defer toml.deep_delete(root, allocator)

    lock.packages = make(map[string]LockEntry, allocator = allocator)

    pkgs_table, pkgs_ok := toml.get_table(root, "packages")
    if pkgs_ok {
        for name, value in pkgs_table {
            entry: LockEntry
            #partial switch v in value {
            case ^toml.Table:
                url_str, url_ok := toml.get_string(v, "url")
                if url_ok {
                    entry.url = strings.clone(url_str, allocator)
                }
                commit_str, commit_ok := toml.get_string(v, "commit")
                if commit_ok {
                    entry.commit = strings.clone(commit_str, allocator)
                }
            }
            lock.packages[strings.clone(name, allocator)] = entry
        }
    }

    return lock, true
}

save_lock_file :: proc(lock: LockFile) -> bool {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    strings.write_string(&builder, "[packages]\n")

    for name, entry in lock.packages {
        fmt.sbprintf(&builder, "%s = {{ url = %q, commit = %q }}\n", name, entry.url, entry.commit)
    }

    return os.write_entire_file(LOCK_FILE, builder.buf[:])
}

create_default_manifest :: proc(name: string) -> bool {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    fmt.sbprintf(&builder, `# endr package manager
# https://github.com/chrishayen/endr

[package]
name = %q
version = "0.1.0"

[dependencies]
`, name)

    return os.write_entire_file(MANIFEST_FILE, builder.buf[:])
}

manifest_add_dependency :: proc(name, url: string, branch, tag: Maybe(string)) -> bool {
    // Read existing file content
    data, ok := os.read_entire_file(MANIFEST_FILE)
    if !ok {
        fmt.eprintln("Error: Could not read", MANIFEST_FILE)
        return false
    }
    defer delete(data)

    content := string(data)
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    // Find the [dependencies] section and add to it
    if strings.contains(content, "[dependencies]") {
        // Add the new dependency at the end of the file
        strings.write_string(&builder, content)
        if !strings.has_suffix(content, "\n") {
            strings.write_string(&builder, "\n")
        }
    } else {
        // No dependencies section, add one
        strings.write_string(&builder, content)
        if !strings.has_suffix(content, "\n") {
            strings.write_string(&builder, "\n")
        }
        strings.write_string(&builder, "\n[dependencies]\n")
    }

    // Write the dependency line
    branch_val, has_branch := branch.?
    tag_val, has_tag := tag.?

    if has_branch || has_tag {
        fmt.sbprintf(&builder, "%s = {{ url = %q", name, url)
        if has_branch {
            fmt.sbprintf(&builder, ", branch = %q", branch_val)
        }
        if has_tag {
            fmt.sbprintf(&builder, ", tag = %q", tag_val)
        }
        strings.write_string(&builder, " }\n")
    } else {
        fmt.sbprintf(&builder, "%s = %q\n", name, url)
    }

    return os.write_entire_file(MANIFEST_FILE, builder.buf[:])
}

manifest_remove_dependency :: proc(name: string) -> bool {
    data, ok := os.read_entire_file(MANIFEST_FILE)
    if !ok {
        fmt.eprintln("Error: Could not read", MANIFEST_FILE)
        return false
    }
    defer delete(data)

    lines := strings.split_lines(string(data))
    defer delete(lines)

    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    for line in lines {
        trimmed := strings.trim_space(line)
        // Skip lines that start with the dependency name
        if strings.has_prefix(trimmed, name) && (strings.contains(trimmed, "=")) {
            // Check if it's actually this dependency (not a substring)
            parts := strings.split_n(trimmed, "=", 2)
            if len(parts) >= 1 && strings.trim_space(parts[0]) == name {
                continue // Skip this line
            }
        }
        strings.write_string(&builder, line)
        strings.write_string(&builder, "\n")
    }

    return os.write_entire_file(MANIFEST_FILE, builder.buf[:])
}
