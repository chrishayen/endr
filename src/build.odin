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
    manifest, manifest_ok := load_manifest(context.temp_allocator)
    if !manifest_ok {
        fmt.eprintln("Error: Could not load", MANIFEST_FILE)
        fmt.eprintln("Run 'endr init' first or create an endr.toml file")
        return false
    }

    // Run pre_build script if defined
    if pre_build, has_pre := manifest.build.pre_build.?; has_pre {
        fmt.printf("Running pre_build: %s\n", pre_build)
        if !run_pre_build(pre_build) {
            fmt.eprintln("Error: pre_build script failed")
            return false
        }
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

    // Add linker flags for native libs
    if native, has_native := manifest.native_libs.?; has_native {
        linker_flags := build_linker_flags(native)
        if len(linker_flags) > 0 {
            append(&command, linker_flags)
        }
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

// Run a pre_build script
run_pre_build :: proc(script: string) -> bool {
    // Determine shell and args based on script
    shell: string
    shell_args: []string

    when ODIN_OS == .Windows {
        shell = "cmd"
        shell_args = {"/c", script}
    } else {
        shell = "sh"
        shell_args = {"-c", script}
    }

    command := make([dynamic]string, context.temp_allocator)
    append(&command, shell)
    for arg in shell_args {
        append(&command, arg)
    }

    process, err := os2.process_start({
        command = command[:],
        stdin   = os2.stdin,
        stdout  = os2.stdout,
        stderr  = os2.stderr,
    })

    if err != nil {
        fmt.eprintf("Error starting pre_build script: %v\n", err)
        return false
    }

    state, wait_err := os2.process_wait(process)
    if wait_err != nil {
        fmt.eprintf("Error waiting for pre_build script: %v\n", wait_err)
        return false
    }

    return state.success
}

// Build linker flags string for native libs
build_linker_flags :: proc(native: NativeLibs) -> string {
    if len(native.libs) == 0 {
        return ""
    }

    builder := strings.builder_make(context.temp_allocator)

    // Start with -extra-linker-flags:"
    strings.write_string(&builder, `-extra-linker-flags:"`)

    // Add library path if specified
    if len(native.path) > 0 {
        fmt.sbprintf(&builder, "-L%s ", native.path)
        // Add rpath for runtime library loading
        when ODIN_OS == .Linux {
            fmt.sbprintf(&builder, `-Wl,-rpath,'$ORIGIN/%s' `, native.path)
        } else when ODIN_OS == .Darwin {
            fmt.sbprintf(&builder, `-Wl,-rpath,@executable_path/%s `, native.path)
        }
    }

    // Add each library
    for lib in native.libs {
        fmt.sbprintf(&builder, "-l%s ", lib)
    }

    strings.write_string(&builder, `"`)

    return strings.to_string(builder)
}

// Get collection flags as a string for display/manual use
get_collection_flags :: proc(allocator := context.allocator) -> string {
    if !os.exists(PACKAGES_DIR) {
        return ""
    }
    return fmt.aprintf("-collection:deps=%s", PACKAGES_DIR, allocator = allocator)
}
