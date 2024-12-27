# Neotest Zig ⚡

![Zig v0.14.0-dev](https://img.shields.io/badge/Zig-v0.14.0_dev-orange?logo=zig)
![Neovim v0.10](https://img.shields.io/badge/Neovim-v0.10-green?logo=neovim)

[Neotest](https://github.com/nvim-neotest/neotest) test runner for [Zig](https://github.com/ziglang/zig).

https://github.com/lawrence-laz/neotest-zig/assets/8823448/9a003d0a-9ba4-4077-aa1b-3c0c90717734

## ⚙️ Requirements
- [`zig` v0.14.0-dev installed](https://ziglang.org/download/) and available in PATH
    - If you are using `zig` v0.13, then use the tagged `neotest-zig` 1.3.* version.
- [Neotest](https://github.com/nvim-neotest/neotest#installation)
- [Treesitter](https://github.com/nvim-treesitter/nvim-treesitter#installation) with [Zig support](https://github.com/maxxnino/tree-sitter-zig)

## 📦 Setup
Install & configure using the package manager of your choice.
Example using lazy.nvim:
```lua
return {
	"nvim-neotest/neotest",
	dependencies = {
		"lawrence-laz/neotest-zig", -- Installation
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"antoinemadec/FixCursorHold.nvim",
	},
	config = function()
		require("neotest").setup({
			adapters = {
				-- Registration
				require("neotest-zig")({
					dap = {
						adapter = "lldb",
					}
				}),
			}
		})
	end
}
```

## ⭐ Features
 - Can run tests in individual `.zig` files and projects using `build.zig` 
   - Does not support a mix of individual files and `build.zig`:w
   - `buil.zig` must have a standard `test` step
 - Exact test filtering
 - Timing all tests individually

## 📄 Logs
Enabling logging in `neotest` automatically enables logging in `neotest-zig` as well:
```lua
require("neotest").setup({
    log_level = vim.log.levels.TRACE,
    -- ...
})
```
The logs can be openned by:
```vim
:exe 'edit' stdpath('log').'/neotest-zig.log'
```
