local async = require("neotest.async")
local lib = require("neotest.lib")
local log = require("neotest-zig.log")

---@type neotest.Adapter
local M = {
	name = "neotest-zig",
	version = "v1.0.5",
}

M.root = lib.files.match_root_pattern(
	"*.zig", -- Search for zig files in current directory.
	".git" -- Search for git repo.
)

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
	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Entered `is_test_file` with", file_path)
		end)
	end
	local result = vim.endswith(file_path, ".zig")
	if (result) then
		result = M._does_file_contain_tests(file_path)
	end
	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Returning from `is_test_file` with", result)
		end)
	end
	return result
end

function M.get_strategy_config(strategy, python, python_script, args)
	log.debug("Entered `get_strategy_config` with", strategy, python, python_script, args)
	local config = {
		dap = nil, -- TODO: Implement DAP support.
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
	(TestDecl
		[(IDENTIFIER) (STRINGLITERALSINGLE)] @test.name
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

---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
function M.build_spec(args)
	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Entered `build_spec` with", args)
		end)
	end
	local tree = args.tree:data()
	if tree.type == "file" or tree.type == "dir" then
		if M._is_debug_log_enabled then
			vim.schedule(function()
				log.debug("Skipping", tree.path, "::", tree.name,
					"because it's a file or a dir, not a test.")
			end)
		end
		return nil
	end

	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Processing test ", tree.path, "::", tree.name)
		end)
	end

	local test_results_path = vim.fs.normalize(async.fn.tempname())
	local test_output_path = vim.fs.normalize(async.fn.tempname())
	local script_path = vim.fs.normalize(debug.getinfo(1).source:sub(2))
	local zig_test_runner_path = vim.fs.normalize(vim.fn.resolve(script_path .. "../../../../zig/neotest-runner.zig"))
	local test_source_path = vim.fs.normalize(tree.name)
	local test_command = 'zig test "' .. tree.path .. '"' ..
	    ' --test-filter ' .. test_source_path ..
	    ' --test-runner "' .. zig_test_runner_path .. '"' ..
	    ' --test-cmd-bin --test-cmd "' .. test_results_path .. '" 2> "' .. test_output_path .. '"'
	local run_spec = {
		command = test_command,
		context = {
			test_results_path = test_results_path,
			test_output_path = test_output_path,
			path = tree.path,
			name = tree.name,
		},
	}
	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Returning from `build_spec` with", run_spec)
		end)
	end
	return run_spec
end

---@async
---@param spec neotest.RunSpec
---@param _ neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
function M.results(spec, _, tree)
	log.debug("Entered `results` with", spec, tree)
	local results = {}
	local test_node = M.get_test_node_by_runspec(tree, spec)
	if test_node == nil then
		error("Could not find a test node for '" .. spec.context.path .. ":" .. spec.context.name .. "'")
	end

	log.debug("Reading output file", spec.context.test_output_path)
	local success_reading, test_output = pcall(lib.files.read, spec.context.test_output_path)
	if success_reading == false then
		error("Could not load test output file at path '" .. spec.context.test_output_path .. "'")
	end
	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Read output file", test_output)
		end)
	end

	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Reading output file", spec.context.test_output_path)
		end)
	end
	local success_reading, test_results_json = pcall(lib.files.read, spec.context.test_results_path)
	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Read output file", test_results_json)
		end)
	end
	if success_reading == false then
		results[test_node.id] = {
			status = "failed",
			output = spec.context.test_output_path,
			short = "Test failed",
		}
		return results
	end
	local test_results = vim.json.decode(test_results_json)
	if M._is_debug_log_enabled then
		vim.schedule(function()
			log.debug("Decoded results JSON", test_results)
		end)
	end
	if test_results == nil then
		error("Could not parse test results file at path '" .. spec.context.test_results_path .. "'")
	end

	for _, result_table in ipairs(test_results) do
		results[test_node.id] = {
			status = result_table.status,
			output = spec.context.test_output_path,
			short = result_table.error_message,
			errors = {
				{
					message = result_table.error_message,
					line = result_table.line - 1
				}
			}
		}
		return results
	end

	results[test_node.id] = {
		status = "Skipped",
		output = spec.context.results_path,
		short = "No results found",
	}
	log.debug("Returning from `results` with", results)
	return results
end

M._is_debug_log_enabled = false
M._debug_log_path = vim.fn.stdpath("data") .. "/neotest-zig.log"
M._enable_debug_log = function()
	log.new({
		use_console = true,
		use_file = true,
		level = "trace",
	}, true)
	M._is_debug_log_enabled = true
end

setmetatable(M, {
	__call = function(_, opts)
		return M.setup(opts)
	end,
})

M.setup = function(opts)
	opts = opts or {}
	if (opts.debug_log) then
		M._enable_debug_log()
	end

	log.debug("Received options", opts)

	log.debug("Setup successful, running version", M.version)
	return M
end

-- Ensure plenary can recognize zig files, otherwise tree sitter functions in neotest fail.
require 'plenary.filetype'.add_table { extension = { zig = 'zig' } }

return M
