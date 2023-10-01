# Neotest Zig ⚡

[Neotest](https://github.com/nvim-neotest/neotest) test runner for [Zig](https://github.com/ziglang/zig).

https://github.com/lawrence-laz/neotest-zig/assets/8823448/2e959ca5-db2a-4eee-a422-48c11e853595

## ⚙️ Requirements
- [`zig` installed](https://ziglang.org/download/) and available in PATH
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
				require("neotest-zig"), -- Registration
			}
		})
	end
}
```
