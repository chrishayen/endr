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

// Remove a directory recursively
remove_directory :: proc(path: string) -> bool {
    // Use os to remove directory
    err := os.remove_directory(path)
    return err == nil
}
