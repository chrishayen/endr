package endr

import "core:os"
import "core:fmt"
import "core:strings"
import "core:path/filepath"

// Install all dependencies from the manifest
install_dependencies :: proc() -> bool {
    manifest, manifest_ok := load_manifest()
    if !manifest_ok {
        fmt.eprintln("Error: Could not load", MANIFEST_FILE)
        return false
    }

    lock, lock_ok := load_lock_file()
    if !lock_ok {
        fmt.eprintln("Error: Could not load lock file")
        return false
    }

    // Create packages directory if it doesn't exist
    if !os.exists(PACKAGES_DIR) {
        err := os.make_directory(PACKAGES_DIR)
        if err != nil {
            fmt.eprintf("Error creating packages directory: %v\n", err)
            return false
        }
    }

    all_success := true

    for name, dep in manifest.dependencies {
        fmt.printf("Installing %s...\n", name)

        dest := filepath.join({PACKAGES_DIR, name}, context.temp_allocator)

        // Check if already installed
        if os.exists(dest) {
            if is_git_repo(dest) {
                // Check if URL matches
                existing_url, url_ok := git_get_remote_url(dest)
                if url_ok && existing_url == dep.url {
                    // Already installed with correct URL
                    // Check if we need to update
                    lock_entry, has_lock := lock.packages[name]

                    commit_val, has_commit := dep.commit.?
                    if has_commit && has_lock && lock_entry.commit == commit_val {
                        fmt.printf("  %s is already at commit %s\n", name, commit_val[:min(len(commit_val), 8)])
                        continue
                    }

                    // Update if needed
                    if !update_dependency(dest, dep) {
                        all_success = false
                        continue
                    }
                } else {
                    // URL changed, remove and re-clone
                    fmt.printf("  URL changed, re-cloning %s\n", name)
                    remove_directory(dest)
                }
            } else {
                // Not a git repo, remove it
                remove_directory(dest)
            }
        }

        // Clone if not exists
        if !os.exists(dest) {
            if !clone_dependency(dep, dest) {
                all_success = false
                continue
            }
        }

        // Update lock file
        commit, commit_ok := git_get_head_commit(dest)
        if commit_ok {
            lock.packages[strings.clone(name)] = LockEntry{
                url    = strings.clone(dep.url),
                commit = commit,
            }
        }

        fmt.printf("  Installed %s\n", name)
    }

    // Save lock file
    if !save_lock_file(lock) {
        fmt.eprintln("Warning: Could not save lock file")
    }

    // Generate OLS config for editor support
    if !generate_ols_config() {
        fmt.eprintln("Warning: Could not generate", OLS_FILE)
    }

    return all_success
}

// Clone a dependency based on its configuration
clone_dependency :: proc(dep: Dependency, dest: string) -> bool {
    branch_val, has_branch := dep.branch.?
    tag_val, has_tag := dep.tag.?
    commit_val, has_commit := dep.commit.?

    if has_branch {
        if !git_clone_branch(dep.url, dest, branch_val) {
            return false
        }
    } else if has_tag {
        if !git_clone_tag(dep.url, dest, tag_val) {
            return false
        }
    } else {
        if !git_clone(dep.url, dest) {
            return false
        }
    }

    // If specific commit is requested, checkout that commit
    if has_commit {
        // Need to fetch full history for specific commit checkout
        if !git_fetch(dest) {
            return false
        }
        if !git_checkout(dest, commit_val) {
            return false
        }
    }

    return true
}

// Update an existing dependency
update_dependency :: proc(dest: string, dep: Dependency) -> bool {
    commit_val, has_commit := dep.commit.?

    if has_commit {
        // Checkout specific commit
        if !git_fetch(dest) {
            return false
        }
        if !git_checkout(dest, commit_val) {
            return false
        }
    } else {
        // Just pull latest
        if !git_pull(dest) {
            return false
        }
    }

    return true
}

// Update packages to latest version
update_packages :: proc(name: Maybe(string)) -> bool {
    manifest, manifest_ok := load_manifest()
    if !manifest_ok {
        fmt.eprintln("Error: Could not load", MANIFEST_FILE)
        return false
    }

    lock, lock_ok := load_lock_file()
    if !lock_ok {
        fmt.eprintln("Error: Could not load lock file")
        return false
    }

    all_success := true
    updated_count := 0

    name_val, has_name := name.?

    for pkg_name, dep in manifest.dependencies {
        if has_name && pkg_name != name_val {
            continue
        }

        dest := filepath.join({PACKAGES_DIR, pkg_name}, context.temp_allocator)

        if !os.exists(dest) {
            fmt.eprintf("Package %s is not installed. Run 'endr install' first.\n", pkg_name)
            all_success = false
            continue
        }

        if !is_git_repo(dest) {
            fmt.eprintf("Package %s is not a git repository\n", pkg_name)
            all_success = false
            continue
        }

        // Skip packages pinned to a specific commit
        _, has_commit := dep.commit.?
        if has_commit {
            fmt.printf("Skipping %s (pinned to specific commit)\n", pkg_name)
            continue
        }

        fmt.printf("Updating %s...\n", pkg_name)

        old_commit, _ := git_get_head_commit(dest)

        if !git_fetch(dest) {
            fmt.eprintf("  Failed to fetch %s\n", pkg_name)
            all_success = false
            continue
        }

        if !git_pull(dest) {
            fmt.eprintf("  Failed to pull %s\n", pkg_name)
            all_success = false
            continue
        }

        new_commit, commit_ok := git_get_head_commit(dest)
        if commit_ok {
            if old_commit != new_commit {
                fmt.printf("  Updated %s: %s -> %s\n", pkg_name, old_commit[:min(len(old_commit), 8)], new_commit[:min(len(new_commit), 8)])
                updated_count += 1
            } else {
                fmt.printf("  %s is already up to date\n", pkg_name)
            }

            lock.packages[strings.clone(pkg_name)] = LockEntry{
                url    = strings.clone(dep.url),
                commit = new_commit,
            }
        }
    }

    if has_name {
        _, found := manifest.dependencies[name_val]
        if !found {
            fmt.eprintf("Package %s not found in %s\n", name_val, MANIFEST_FILE)
            return false
        }
    }

    if !save_lock_file(lock) {
        fmt.eprintln("Warning: Could not save lock file")
    }

    if updated_count > 0 {
        fmt.printf("Updated %d package(s)\n", updated_count)
    } else if all_success {
        fmt.println("All packages are up to date")
    }

    return all_success
}

// Remove a directory recursively
remove_directory :: proc(path: string) -> bool {
    // Use os to remove directory
    err := os.remove_directory(path)
    return err == nil
}
