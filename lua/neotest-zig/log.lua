local log = {}

local log_levels = vim.log.levels

--- Log level dictionary with reverse lookup as well.
---
--- Can be used to lookup the number from the name or the name from the number.
--- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
--- Level numbers begin with "TRACE" at 0
--- @type table<string|integer, string|integer>
--- @nodoc
log.levels = vim.deepcopy(log_levels)

-- Log level is same as in neotest
local current_log_level = function()
    return require("neotest.config").log_level
end

local log_date_format = '%F %H:%M:%S'

local function format_func(arg)
    return vim.inspect(arg, { newline = '\n' })
end

local function notify(msg, level)
    if vim.in_fast_event() then
        vim.schedule(function()
            vim.notify(msg, level)
        end)
    else
        vim.notify(msg, level)
    end
end

local logfilename = vim.fs.normalize(vim.fn.stdpath('log') .. '/' .. 'neotest-zig.log')

vim.fn.mkdir(vim.fn.stdpath('log'), 'p')

--- Returns the log filename.
---@return string log filename
function log.get_filename()
    return logfilename
end

--- @type file*?, string?
local logfile, openerr

--- Opens log file. Returns true if file is open, false on error
local function open_logfile()
    -- Try to open file only once
    if logfile then
        return true
    end
    if openerr then
        return false
    end

    logfile, openerr = io.open(logfilename, 'a+')
    if not logfile then
        local err_msg = string.format('Failed to open neotest-zig log file: %s', openerr)
        notify(err_msg, log_levels.ERROR)
        return false
    end

    local log_info = vim.uv.fs_stat(logfilename)
    if log_info and log_info.size > 1e9 then
        local warn_msg = string.format(
            'neotest-zig log is large (%d MB): %s',
            log_info.size / (1000 * 1000),
            logfilename
        )
        notify(warn_msg)
    end

    -- Start message for logging
    logfile:write(string.format('[START][%s] neotest-zig logging initiated\n', os.date(log_date_format)))
    return true
end

for level, levelnr in pairs(log_levels) do
    -- Also export the log level on the root object.
    log[level] = levelnr

    -- Add a reverse lookup.
    log.levels[levelnr] = level
end

--- @param level string
--- @param levelnr integer
--- @return fun(...:any): boolean?
local function create_logger(level, levelnr)
    return function(...)
        if levelnr < current_log_level() then
            return false
        end
        local argc = select('#', ...)
        if argc == 0 then
            return true
        end
        if not open_logfile() then
            return false
        end
        local info = debug.getinfo(2, 'Sl')
        local header = string.format(
            '[%s][%s] ...%s:%s',
            level,
            os.date(log_date_format),
            info.short_src:sub(-16),
            info.currentline
        )
        local parts = { header }
        for i = 1, argc do
            local arg = select(i, ...)
            table.insert(parts, arg == nil and 'nil' or format_func(arg))
        end
        assert(logfile)
        logfile:write(table.concat(parts, '\t'), '\n')
        logfile:flush()
    end
end

--- @nodoc
log.debug = create_logger('DEBUG', log_levels.DEBUG)

--- @nodoc
log.error = create_logger('ERROR', log_levels.ERROR)

--- @nodoc
log.info = create_logger('INFO', log_levels.INFO)

--- @nodoc
log.trace = create_logger('TRACE', log_levels.TRACE)

--- @nodoc
log.warn = create_logger('WARN', log_levels.WARN)

--- @return number
log.get_log_level = function()
    return current_log_level()
end

-- --- Sets formatting function used to format logs
-- ---@param handle function function to apply to logging arguments, pass vim.inspect for multi-line formatting
-- function log.set_format_func(handle)
--     assert(handle == vim.inspect or type(handle) == 'function', 'handle must be a function')
--     format_func = handle
-- end

return log
