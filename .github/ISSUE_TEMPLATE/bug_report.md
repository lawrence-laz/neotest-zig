---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

## **Steps To Reproduce**
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'

## **Current behavior**
A clear and concise description of what currently happenned.

## **Expected behavior**
A clear and concise description of what you expected to happen.

## **Screenshots**
If applicable, add screenshots to help explain your problem.

## **Logs**
Enable logs with:
```lua
require("neotest").setup({
	adapters = {
		require("neotest-zig") {
			debug_log = true
		}
	}
})
```
Read-only logs path is available in:
`:lua =(vim.fn.stdpath("data") .. "/neotest-zig.log")`

## **Environment**
 - OS: 
 - Zig version:
 - Nvim version:
 - Neotest version:
 - Neotest Zig version:

## **Additional context**
Add any other context about the problem here.
