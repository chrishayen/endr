package endr

import "core:os"
import "core:os/os2"
import "core:fmt"
import "core:strings"

// Build the project using odin with collection flags for dependencies
build_project :: proc(args: []string) -> bool {
    return run_odin("build", args, false)
}

// Run the project using odin with collection flags for dependencies
run_project :: proc(args: []string) -> bool {
    return run_odin("run", args, true)
}

// Run odin with the given command (build/run) and collection flags
run_odin :: proc(cmd: string, args: []string, use_temp_out: bool) -> bool {
    if !os.exists(MANIFEST_FILE) {
        fmt.eprintln("Error: Could not load", MANIFEST_FILE)
        fmt.eprintln("Run 'endr init' first or create an endr.toml file")
        return false
    }

    // Build command array
    command := make([dynamic]string, context.temp_allocator)
    append(&command, "odin")
    append(&command, cmd)

    // Add user-provided arguments first (directory must come before flags)
    for arg in args {
        append(&command, arg)
    }

    // For 'run', use a temp output name to avoid clobbering build artifacts
    if use_temp_out {
        append(&command, "-out:.endr/temp_run")
    }

    // Add deps collection pointing to packages directory
    if os.exists(PACKAGES_DIR) {
        flag := fmt.tprintf("-collection:deps=%s", PACKAGES_DIR)
        append(&command, flag)
    }

    // Execute odin
    fmt.printf("Running: %s\n", strings.join(command[:], " "))

    process, err := os2.process_start({
        command = command[:],
        stdin   = os2.stdin,
        stdout  = os2.stdout,
        stderr  = os2.stderr,
    })

    if err != nil {
        fmt.eprintf("Error starting odin: %v\n", err)
        return false
    }

    state, wait_err := os2.process_wait(process)
    if wait_err != nil {
        fmt.eprintf("Error waiting for odin: %v\n", wait_err)
        return false
    }

    return state.success
}

// Get collection flags as a string for display/manual use
get_collection_flags :: proc(allocator := context.allocator) -> string {
    if !os.exists(PACKAGES_DIR) {
        return ""
    }
    return fmt.aprintf("-collection:deps=%s", PACKAGES_DIR, allocator = allocator)
}
