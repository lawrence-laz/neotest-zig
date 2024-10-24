local async = require("neotest.async")
local lib = require("neotest.lib")
local log = require("neotest-zig.log")
local Path = require("plenary.path")
local nio = require("nio")

---@class ZigTestInput
---@field test_name string
---@field source_path string
---@field output_path string

---@class ZigTestError
---@field message string
---@field line? integer

---@class ZigTestResult
---@field test_name string
---@field source_path string
---@field output string Path to file containing full output data
---@field status "passed"|"failed"|"skipped"
---@field short string Shortened output string
---@field errors ZigTestError[]

---@type neotest.Adapter
local M = {
    name = "neotest-zig",
    version = "v1.1.0",
    dap = {
        adapter = "",
    },
    path_to_zig = "zig",
}

function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

local tbl_flatten = function(table)
    return nio.fn.has("nvim-0.11") == 1 and vim.iter(table):flatten():totable()
        or vim.tbl_flatten(table)
end

--- Create a function that will take directory and attempt to match the provided
--- glob patterns against the contents of the directory.
--- [!] This is a modified copy of a standard neotest function,
--- which avoids checking directories above the current working directory.
---@param ... string Patterns to match e.g "*.zig"
---@return fun(path: string): string | nil
function M.match_root_pattern(...)
    local patterns = tbl_flatten({ ... })
    return function(start_path)
        log.trace("Entered match_root_pattern with", start_path)
        local start_parents = Path:new(start_path):parents()
        local home = os.getenv("HOME")
        local potential_roots = lib.files.is_dir(start_path)
            and vim.list_extend({ start_path }, start_parents)
            or start_parents
        local valid_roots = {}
        for index, value in ipairs(potential_roots) do
            if value == home then
                break
            end
            if not string.starts(vim.fs.normalize(value), vim.fs.normalize(vim.loop.cwd())) then
                break
            end
            log.trace("Found a valid root", value)
            valid_roots[index] = value
        end
        for _, path in ipairs(valid_roots) do
            for _, pattern in ipairs(patterns) do
                for _, p in ipairs(nio.fn.glob(Path:new(path, pattern).filename, true, true)) do
                    if lib.files.exists(p) then
                        log.trace("Return from match_root_pattern with", path)
                        return path
                    end
                end
            end
        end
    end
end

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
M.root = M.match_root_pattern("build.zig")

M.filter_dir = function(name, rel_path, root)
    log.trace("Entered filter_dir with", name, rel_path, root);
    if name == "zig-cache" or name == "zig-out" then
        return false
    else
        return true
    end
end

---@param tree neotest.Tree
---@param spec neotest.RunSpec
function M.get_test_node_by_runspec(tree, spec)
    log.debug("Entered `get_test_node_by_runspec` with", tree, spec)
    for _, node in tree:iter_nodes() do
        local test_node = node:data()
        if test_node.path == spec.context.path and test_node.name == spec.context.name then
            log.debug("Returning from `get_test_node_by_runspec` with", test_node)
            return test_node
        end
    end
    log.debug("Returning from `get_test_node_by_runspec` with nil")
    return nil
end

function M.is_test_file(file_path)
    log.debug("Entered `is_test_file` with", file_path)
    local result = vim.endswith(file_path, ".zig")
    if (result) then
        result = M._does_file_contain_tests(file_path)
    end
    log.debug("Returning from `is_test_file` with", result)
    return result
end

function M.get_strategy_config(strategy, python, python_script, args)
    log.debug("Entered `get_strategy_config` with", strategy, python, python_script, args)
    local config = {
        dap = nil, -- DAP is handled in build spec functions.
    }
    if config[strategy] then
        local result = config[strategy]()
        log.debug("Returning from `get_strategy_config` with", result)
        return result
    end
    log.debug("Returning from `get_strategy_config` with nil")
end

M._test_treesitter_query = [[
	;;query
    (test_declaration
        [(identifier) (string)] @test.name
    ) @test.definition
]]

function M._does_file_contain_tests(file_path)
    local content = lib.files.read(file_path)
    local tree = lib.treesitter.parse_positions_from_string(file_path, content, M._test_treesitter_query, {})
    local contains_tests = next(tree._children) ~= nil
    return contains_tests
end

---@async
---@return neotest.Tree | nil
function M.discover_positions(path)
    log.debug("Entered `discover_positions` with", path)
    log.debug("Running query", M._test_treesitter_query)
    local positions = lib.treesitter.parse_positions(path, M._test_treesitter_query, { nested_namespaces = true })
    log.debug("Returning from `discover_positions` with", positions)
    return positions
end

function M._get_temp_file_path()
    return vim.fs.normalize(async.fn.tempname())
end

local function choose_program()
    local test_program_paths = vim.fn.glob(vim.fn.getcwd() .. "/zig-out/test/*")
    local _, programs_count = test_program_paths:gsub('\n', '\n')
    log.debug("tests", test_program_paths)

    local program_path = ""
    if (programs_count > 0) then
        program_path = vim.fn.input(
            "Found multiple programs to debug, choose one:\n" .. test_program_paths .. "\n\nPath to executable: ",
            vim.fn.glob(vim.fn.getcwd() .. "/zig-out/test/"),
            "file")
    else
        program_path = test_program_paths
    end
    return program_path
end

local function build_async(build_file, runner_file, on_success, on_failure)
    vim.system({
        M.path_to_zig,
        "build",
        "neotest-build",
        "--build-file",
        build_file,
        "-Dneotest-runner=" .. runner_file

    }, { text = true }, function(out)
        if (out.code == 0) then
            on_success(true)
        else
            log.error("out", out)
            on_failure(out.stderr)
        end
    end)
end
---@param args neotest.RunArgs
---@param build_file_path string
---@return neotest.RunSpec | nil
function M._build_spec_with_buildfile(args, build_file_path)
    log.debug("Entered `_build_spec_with_buildfile`")
    local neotest_inputs = {}
    for _, node in args.tree:iter_nodes() do
        if node:data().type ~= "test" then
            goto continue
        end

        local test_name = M._get_zig_symbol_name_from_node(node)

        table.insert(neotest_inputs, {
            test_name = test_name,
            source_path = node:data().path,
            output_path = M._get_temp_file_path(),
        })
        ::continue::
    end

    log.debug("Processing tests from '", args.tree:data().path, "::", args.tree:data().name,
        "', found ",
        #neotest_inputs,
        " tests")
    log.debug("Inputs are:", neotest_inputs)

    local neotest_input_path = M._get_temp_file_path()
    local neotest_input_json = vim.json.encode(neotest_inputs)
    local success_writing, test_results_json = pcall(lib.files.write, neotest_input_path, neotest_input_json)
    if not success_writing then
        log.error("Could not write into:", neotest_input_path)
        return
    end

    log.debug("Successfully wrote test input into", neotest_input_path)

    local neotest_results_path = M._get_temp_file_path()

    vim.loop.fs_mkdir(neotest_results_path, 493) -- Ensure tests results dir before running tests.
    local this_script_path = vim.fs.normalize(debug.getinfo(1).source:sub(2))
    local source_neotest_build_file_path = vim.fs.normalize(
        vim.fn.resolve(this_script_path .. "../../../../zig/neotest_build.zig"))
    local test_runner_path = vim.fs.normalize(
        vim.fn.resolve(this_script_path .. "../../../../zig/neotest_runner.zig"))

    local build_file_dir_path = build_file_path:match("(.*[/\\])")
    local target_neotest_build_file_path = build_file_dir_path .. "neotest_build.zig";

    local success, errmsg = vim.loop.fs_copyfile(source_neotest_build_file_path, target_neotest_build_file_path)
    if not success then
        log.error("Could not copy from", source_neotest_build_file_path, "to", target_neotest_build_file_path)
        return
    end

    local context = {
        temp_neotest_build_file_path = target_neotest_build_file_path,
        test_results_dir_path = neotest_results_path,
    }

    -- Test runner logs have a separate directory, because
    -- Zig may launch multiple processes, where each process
    -- would write into a separate log file.
    local test_runner_logs_dir_path = M._get_temp_file_path()
    vim.loop.fs_mkdir(test_runner_logs_dir_path, 493)

    local zig_test_command = M.path_to_zig ..
        ' build test' ..
        ' --build-file "' .. target_neotest_build_file_path .. '"' ..
        ' -Dneotest-runner="' .. test_runner_path .. '"' ..
        ' -- ' ..
        ' --neotest-input-path "' .. neotest_input_path .. '"' ..
        ' --neotest-results-path "' .. neotest_results_path .. '"' ..
        ' --test-runner-logs-path "' .. test_runner_logs_dir_path .. '"' ..
        ' --test-runner-log-level "' .. log.get_log_level() .. '"'

    local run_spec = {
        command = zig_test_command,
        context = context,
    }

    if (args.strategy == "dap") then
        local future = nio.control.future()
        build_async(target_neotest_build_file_path, test_runner_path,
            function()
                future.set()
            end,
            function(error)
                future.set_error(error)
            end
        )
        local build_success, build_error_message = pcall(future.wait)
        run_spec.strategy = {
            name = "Debug with neotest-zig",
            type = M.dap.adapter,
            request = "launch",
            args = {
                '--neotest-input-path', neotest_input_path,
                '--neotest-results-path', neotest_results_path,
                '--test-runner-logs-path', test_runner_logs_dir_path,
                '--test-runner-log-level', '' .. log.get_log_level(),
            }
        }
        if build_success then
            run_spec.strategy.program = choose_program
        else
            run_spec.context.dap_build_error = build_error_message
        end
    end
    return run_spec
end

---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
function M._build_spec_without_buildfile(args)
    -- TODO: Handle non build.zig debugging, see "Equivalent to running the command `zig test --test-no-exec ...`"
    -- zig test by specifying the executable location with -femit-bin --test-no-exec

    log.debug("Entered `_build_spec_without_buildfile`")
    local neotest_inputs = {}
    local source_path = ""

    if args.tree:data().type ~= "test" then
        for _, node in args.tree:iter_nodes() do
            if node:data().type ~= "test" then
                goto continue
            end

            local test_name = M._get_zig_symbol_name_from_node(node)
            source_path = node:data().path
            table.insert(neotest_inputs, {
                test_name = test_name,
                source_path = node:data().path,
                output_path = M._get_temp_file_path(),
            })
            ::continue::
        end
    else
        local node = args.tree
        local test_name = M._get_zig_symbol_name_from_node(node)
        source_path = node:data().path
        table.insert(neotest_inputs, {
            test_name = test_name,
            source_path = node:data().path,
            output_path = M._get_temp_file_path(),
        })
    end

    log.debug("Processing tests from '", args.tree:data().path, "::", args.tree:data().name,
        "', found ",
        #neotest_inputs,
        " tests")
    log.debug("Inputs are:", neotest_inputs)

    local neotest_input_path = M._get_temp_file_path()
    local neotest_input_json = vim.json.encode(neotest_inputs)
    local success_writing, test_results_json = pcall(lib.files.write, neotest_input_path, neotest_input_json)
    if not success_writing then
        log.fatal("Could not write into:", neotest_input_path)
        return
    end

    local neotest_results_path = M._get_temp_file_path()
    vim.loop.fs_mkdir(neotest_results_path, 493)
    local this_script_path = vim.fs.normalize(debug.getinfo(1).source:sub(2))
    local zig_test_runner_path = vim.fs.normalize(
        vim.fn.resolve(this_script_path .. "../../../../zig/neotest_runner.zig"))

    local test_runner_logs_dir_path = M._get_temp_file_path()
    vim.loop.fs_mkdir(test_runner_logs_dir_path, 493)

    local zig_test_command = M.path_to_zig ..
        ' test ' ..
        source_path ..
        ' --test-runner "' .. zig_test_runner_path .. '" ' ..
        ' --test-cmd-bin' ..
        ' --test-cmd "' .. '--neotest-input-path' .. '"' ..
        ' --test-cmd "' .. neotest_input_path .. '"' ..
        ' --test-cmd "' .. '--neotest-results-path' .. '"' ..
        ' --test-cmd "' .. neotest_results_path .. '"' ..
        ' --test-cmd "' .. '--neotest-source-path' .. '"' ..
        ' --test-cmd "' .. source_path .. '"' ..
        ' --test-cmd "' .. '--test-runner-logs-path' .. '"' ..
        ' --test-cmd "' .. test_runner_logs_dir_path .. '"' ..
        ' --test-cmd "' .. '--test-runner-log-level' .. '"' ..
        ' --test-cmd "' .. log.get_log_level() .. '"'

    local run_spec = {
        command = zig_test_command,
        context = {
            test_results_dir_path = neotest_results_path,
        },
    }
    return run_spec
end

---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
function M.build_spec(args)
    log.debug("Entered `build_spec` with", args)

    local run_spec = nil
    local root_path = args.tree:root():data().path
    log.trace("Looking for `build.zig` file with glob pattern", root_path .. "**/build.zig")
    local build_file_path_matches = require("nio").fn.glob(root_path .. "**/build.zig", false, true)
    log.trace("Build file path matches", build_file_path_matches)
    local build_file_path = ""
    if (#build_file_path_matches > 0) then
        log.trace("Found ", #build_file_path_matches, " `build.zig` files")
        build_file_path = build_file_path_matches[1]
    end
    local use_build_file = build_file_path ~= nil and build_file_path ~= ""
    log.trace("Use build file is set to", use_build_file)

    if use_build_file then
        run_spec = M._build_spec_with_buildfile(args, build_file_path)
    else
        if args.tree:data().type == "file" then
            run_spec = M._build_spec_without_buildfile(args)
        elseif args.tree:data().type == "test" then
            run_spec = M._build_spec_without_buildfile(args)
        else
            -- Skipping non-file/non-test nodes, since `zig test` runs on file-level only.
            -- This will make neotest core call the function again with descending files.
            return nil
        end
    end

    log.debug("Returning from `build_spec` with", run_spec)
    return run_spec
end

---@param node neotest.Tree
---@return string
function M._get_zig_symbol_name_from_node(node)
    -- Tests in Zig can be named either by a string, or by another declaration.
    local test_name = ""
    local test_name_starts_with_doublequote = string.sub(node:data().name, 1, 1) == "\""
    if test_name_starts_with_doublequote then
        test_name = "test." .. string.sub(node:data().name, 2, string.len(node:data().name) - 1)
    else
        test_name = "decltest." .. node:data().name
    end
    return test_name
end

---@param source_path string
---@param test_name string
---@param zig_test_results ZigTestResult[]
---@return neotest.Result?
function M._get_neotest_result(source_path, test_name, zig_test_results)
    for _, zig_test_result in ipairs(zig_test_results) do
        if zig_test_result.test_name == test_name and zig_test_result.source_path == source_path then
            ---@type neotest.Result
            local result = {
                status = zig_test_result.status,
                short = zig_test_result.short,
                errors = zig_test_result.errors or {},
                output = zig_test_result.output,
            }
            return result
        end
    end
    return nil
end

local function handle_run_error(result, context)
    if context.dap_build_error then
        vim.notify("Build error when lauching tests:\n" .. context.dap_build_error, vim.log.levels.ERROR,
            { title = "neotest-zig" })
        return true, {
            status = "error",
            short = "build failed before launching debugger",
            errors = context.dap_build_error
        }
    end
    if result.code ~= 0 then
        local success, exit_error_result = pcall(lib.files.read, result.output)
        local message = success and exit_error_result or
            "test failed to run AND failed to read error output"
        return true, {
            status = "error",
            short = "build or run returned non-zero exit code",
            errors = message,
        }
    end
    return false, nil
end

---@async
---@param spec neotest.RunSpec
---@param _ neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
function M.results(spec, result, tree)
    log.trace("Entered `results` with", spec, tree)

    if spec.context.temp_neotest_build_file_path then
        local success = pcall(os.remove, spec.context.temp_neotest_build_file_path)
        if not success then
            log.debug("Could not delete `temp_neotest_build_file_path`", spec.context.temp_neotest_build_file_path)
        end
    end


    local has_non_zero_exit, exit_message = handle_run_error(result, spec.context)
    if has_non_zero_exit then
        return {
            run = exit_message
        }
    end

    local neotest_results = {}

    if not lib.files.exists(spec.context.test_results_dir_path) then
        log.fatal("Dir `test_results_dir_path` does not exists", spec.context.test_results_dir_path)
        return neotest_results
    end

    local zig_test_results = {}
    for test_results_file_name, type in vim.fs.dir(spec.context.test_results_dir_path) do
        log.trace("Found a ", type, "named", test_results_file_name, "in results dir");
        if (type ~= "file") then
            goto continue
        end

        local test_results_file_path = vim.fs.normalize(
            spec.context.test_results_dir_path .. "/" .. test_results_file_name
        )

        log.trace("Trying to open results file", test_results_file_path)
        local success, test_results_json = pcall(lib.files.read, test_results_file_path)
        if not success then
            log.error("Could not open results file", test_results_file_path)
            goto continue
        end

        local test_results = vim.json.decode(test_results_json, { luanil = { object = true, array = true } })

        log.trace("Decoded JSON", test_results)

        vim.list_extend(zig_test_results, test_results)

        ::continue::
    end

    for _, node in tree:iter_nodes() do
        if node:data().type ~= "test" then
            goto continue
        end

        local test_name = M._get_zig_symbol_name_from_node(node)

        neotest_results[node:data().id] = M._get_neotest_result(node:data().path, test_name, zig_test_results)
            or {
                status = "skipped",
                short = "No results found. Make sure the test is included in build.",
                errors = {},
            }

        ::continue::
    end

    log.trace("Returning from `results` with", neotest_results)

    return neotest_results
end

setmetatable(M, {
    __call = function(_, opts)
        return M.setup(opts)
    end,
})

M.setup = function(opts)
    opts = opts or {}

    M.dap = vim.tbl_extend("force", {
        adapter = "lldb",
    }, opts.dap or {})

    if opts.path_to_zig then
      M.path_to_zig = opts.path_to_zig
    end

    log.debug("Received options", opts)
    log.info("Setup successful, running version", M.version)
    return M
end

-- Ensure plenary can recognize zig files, otherwise tree sitter functions in neotest fail.
require 'plenary.filetype'.add_table { extension = { zig = 'zig' } }

return M
