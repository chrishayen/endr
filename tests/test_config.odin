package tests

import "core:testing"
import "core:os"
import "core:strings"
import endr "../src"

@(test)
test_extract_repo_name :: proc(t: ^testing.T) {
    // Test with .git suffix
    name1 := endr.extract_repo_name("https://github.com/user/repo.git")
    testing.expect_value(t, name1, "repo")

    // Test without .git suffix
    name2 := endr.extract_repo_name("https://github.com/user/repo")
    testing.expect_value(t, name2, "repo")

    // Test with longer path
    name3 := endr.extract_repo_name("https://github.com/org/team/repo")
    testing.expect_value(t, name3, "repo")
}

@(test)
test_escape_json_string :: proc(t: ^testing.T) {
    // Test no escaping needed
    result1 := endr.escape_json_string("simple")
    testing.expect_value(t, result1, "simple")

    // Test backslash escaping
    result2 := endr.escape_json_string("path\\to\\file")
    testing.expect_value(t, result2, "path\\\\to\\\\file")

    // Test quote escaping
    result3 := endr.escape_json_string(`say "hello"`)
    testing.expect_value(t, result3, `say \"hello\"`)
}

@(test)
test_build_linker_flags_empty :: proc(t: ^testing.T) {
    native := endr.NativeLibs{}
    result := endr.build_linker_flags(native)
    testing.expect_value(t, result, "")
}

@(test)
test_build_linker_flags_with_libs :: proc(t: ^testing.T) {
    native := endr.NativeLibs{
        path = "",
        libs = {},
    }
    append(&native.libs, "clarity")
    append(&native.libs, "face")

    result := endr.build_linker_flags(native)
    testing.expect(t, len(result) > 0, "Expected non-empty linker flags")
    testing.expect(t, contains(result, "-lclarity"), "Expected -lclarity in flags")
    testing.expect(t, contains(result, "-lface"), "Expected -lface in flags")
}

@(test)
test_build_linker_flags_with_path :: proc(t: ^testing.T) {
    native := endr.NativeLibs{
        path = "build/lib",
        libs = {},
    }
    append(&native.libs, "mylib")

    result := endr.build_linker_flags(native)
    testing.expect(t, contains(result, "-Lbuild/lib"), "Expected -L path in flags")
    testing.expect(t, contains(result, "-lmylib"), "Expected -lmylib in flags")
}

contains :: proc(s: string, substr: string) -> bool {
    return strings.contains(s, substr)
}
