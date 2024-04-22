# Neotest Zig ⚡

> [!NOTE]
> Zig 0.12 version is being worked on in [branch v1.2.0](https://github.com/lawrence-laz/neotest-zig/tree/v1.2.0). It will feature a rewrite on the runner, which will enable testing and debugging projects using `build.zig`.

[Neotest](https://github.com/nvim-neotest/neotest) test runner for [Zig](https://github.com/ziglang/zig).

https://github.com/lawrence-laz/neotest-zig/assets/8823448/9a003d0a-9ba4-4077-aa1b-3c0c90717734

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
