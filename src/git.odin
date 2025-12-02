package endr

import "core:os"
import "core:os/os2"
import "core:fmt"
import "core:strings"

// Clone a git repository to the destination path
git_clone :: proc(url, dest: string) -> bool {
    state, stdout, stderr, err := os2.process_exec({
        command = {"git", "clone", "--depth", "1", url, dest},
    }, context.temp_allocator)

    if err != nil {
        fmt.eprintf("Error starting git clone: %v\n", err)
        return false
    }

    if !state.success {
        fmt.eprintf("git clone failed:\n%s\n", string(stderr))
        return false
    }

    return true
}

// Clone with a specific branch
git_clone_branch :: proc(url, dest, branch: string) -> bool {
    state, stdout, stderr, err := os2.process_exec({
        command = {"git", "clone", "--depth", "1", "--branch", branch, url, dest},
    }, context.temp_allocator)

    if err != nil {
        fmt.eprintf("Error starting git clone: %v\n", err)
        return false
    }

    if !state.success {
        fmt.eprintf("git clone failed:\n%s\n", string(stderr))
        return false
    }

    return true
}

// Clone with a specific tag
git_clone_tag :: proc(url, dest, tag: string) -> bool {
    state, stdout, stderr, err := os2.process_exec({
        command = {"git", "clone", "--depth", "1", "--branch", tag, url, dest},
    }, context.temp_allocator)

    if err != nil {
        fmt.eprintf("Error starting git clone: %v\n", err)
        return false
    }

    if !state.success {
        fmt.eprintf("git clone failed:\n%s\n", string(stderr))
        return false
    }

    return true
}

// Fetch updates from remote
git_fetch :: proc(repo_path: string) -> bool {
    state, stdout, stderr, err := os2.process_exec({
        command     = {"git", "fetch", "--all"},
        working_dir = repo_path,
    }, context.temp_allocator)

    if err != nil {
        fmt.eprintf("Error starting git fetch: %v\n", err)
        return false
    }

    if !state.success {
        fmt.eprintf("git fetch failed:\n%s\n", string(stderr))
        return false
    }

    return true
}

// Checkout a specific ref (branch, tag, or commit)
git_checkout :: proc(repo_path, ref: string) -> bool {
    state, stdout, stderr, err := os2.process_exec({
        command     = {"git", "checkout", ref},
        working_dir = repo_path,
    }, context.temp_allocator)

    if err != nil {
        fmt.eprintf("Error starting git checkout: %v\n", err)
        return false
    }

    if !state.success {
        fmt.eprintf("git checkout failed:\n%s\n", string(stderr))
        return false
    }

    return true
}

// Get the current HEAD commit hash
git_get_head_commit :: proc(repo_path: string, allocator := context.allocator) -> (commit: string, ok: bool) {
    state, stdout, stderr, err := os2.process_exec({
        command     = {"git", "rev-parse", "HEAD"},
        working_dir = repo_path,
    }, context.temp_allocator)

    if err != nil {
        fmt.eprintf("Error starting git rev-parse: %v\n", err)
        return "", false
    }

    if !state.success {
        fmt.eprintf("git rev-parse failed:\n%s\n", string(stderr))
        return "", false
    }

    // Trim whitespace from output
    result := strings.trim_space(string(stdout))
    return strings.clone(result, allocator), true
}

// Pull latest changes
git_pull :: proc(repo_path: string) -> bool {
    state, stdout, stderr, err := os2.process_exec({
        command     = {"git", "pull"},
        working_dir = repo_path,
    }, context.temp_allocator)

    if err != nil {
        fmt.eprintf("Error starting git pull: %v\n", err)
        return false
    }

    if !state.success {
        fmt.eprintf("git pull failed:\n%s\n", string(stderr))
        return false
    }

    return true
}

// Check if a directory is a git repository
is_git_repo :: proc(path: string) -> bool {
    git_dir := strings.concatenate({path, "/.git"}, context.temp_allocator)
    return os.is_dir(git_dir)
}

// Get remote URL
git_get_remote_url :: proc(repo_path: string, allocator := context.allocator) -> (url: string, ok: bool) {
    state, stdout, stderr, err := os2.process_exec({
        command     = {"git", "remote", "get-url", "origin"},
        working_dir = repo_path,
    }, context.temp_allocator)

    if err != nil {
        return "", false
    }

    if !state.success {
        return "", false
    }

    result := strings.trim_space(string(stdout))
    return strings.clone(result, allocator), true
}
