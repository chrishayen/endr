package endr

import "core:os"
import "core:fmt"
import "core:strings"

OLS_FILE :: "ols.json"

// Generate or update ols.json for editor/LSP support
generate_ols_config :: proc() -> bool {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    // Get Odin root from environment for core/vendor collections
    odin_root := os.get_env("ODIN_ROOT", context.temp_allocator)

    strings.write_string(&builder, "{\n")
    strings.write_string(&builder, `    "$schema": "https://raw.githubusercontent.com/DanielGavin/ols/master/misc/ols.schema.json",`)
    strings.write_string(&builder, "\n    \"collections\": [\n")

    // Add core and vendor if ODIN_ROOT is set
    if odin_root != "" {
        fmt.sbprintf(&builder, "        {{ \"name\": \"core\", \"path\": \"%s/core\" }},\n", escape_json_string(odin_root))
        fmt.sbprintf(&builder, "        {{ \"name\": \"vendor\", \"path\": \"%s/vendor\" }},\n", escape_json_string(odin_root))
    }

    // Add the deps collection for endr packages
    fmt.sbprintf(&builder, "        {{ \"name\": \"deps\", \"path\": \"%s\" }}\n", PACKAGES_DIR)

    strings.write_string(&builder, "    ],\n")
    strings.write_string(&builder, "    \"enable_document_symbols\": true,\n")
    strings.write_string(&builder, "    \"enable_hover\": true,\n")
    strings.write_string(&builder, "    \"enable_snippets\": true\n")
    strings.write_string(&builder, "}\n")

    return os.write_entire_file(OLS_FILE, builder.buf[:])
}

// Escape special characters for JSON strings
escape_json_string :: proc(s: string) -> string {
    if !strings.contains_any(s, "\\\"") {
        return s
    }

    builder := strings.builder_make(context.temp_allocator)
    for c in s {
        switch c {
        case '\\':
            strings.write_string(&builder, "\\\\")
        case '"':
            strings.write_string(&builder, "\\\"")
        case:
            strings.write_byte(&builder, u8(c))
        }
    }
    return strings.to_string(builder)
}
