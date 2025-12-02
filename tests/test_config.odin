package tests

import "core:testing"
import "core:os"
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
