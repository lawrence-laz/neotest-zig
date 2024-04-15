1. Running tests when `build.zig` is present (`zig build test`)
    1.1. Run individual test
    1.2. Run individual file
    1.3. Run directory
    1.4. Run all directories
    1.5. Run with multiple `build.zig` present

2. Running tests when `build.zig` is **NOT** present (`zig test`)
    2.1. Run individual test
    2.2. Run individual file
    2.3. Run directory
    2.4. Run all directories

3. When tests fail to build, it should show up as error with output
    3.1. For `zig build test`
    3.2. For `zig test`

4. Logging
    4.1. When disabled shouldn't write anything (lua and zig)
    4.2. When enabled should write according to level (lua and zig)

5. Detecting zig projects
    5.1. When directory does not contain zig code, should not populate "Neotest Summary"
    5.2. When directory contains zig code, should populate "Neotest Summary"

6. Handle statuses
    6.1. Pass
    6.2. Fail
    6.3. Skip

7. Provide error messages with line numbers

8. Provide "short" text output version

9. Modifying tests
    9.1. Add new file
    9.2. Add new test
    9.3. Remove test
    9.4. Remove file

10. 🚧 Debug test

11. Writing to `std.debug.print` and `std.log.info` should appear in tests output
