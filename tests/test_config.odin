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
