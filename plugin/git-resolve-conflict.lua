-- Git Resolve Conflict Plugin Setup
-- Commands and global configuration

local git_resolve = require("git-resolve-conflict")

-- Commands
vim.api.nvim_create_user_command("GitResolve", function(opts)
	local strategy = opts.args
	if strategy == "" then
		git_resolve.pick_and_resolve()
	else
		git_resolve.resolve_file(strategy)
	end
end, {
	desc = "Resolve conflicts (ours|theirs|union)",
	nargs = "?",
	complete = function()
		return { "ours", "theirs", "union" }
	end,
})

vim.api.nvim_create_user_command("GitResolveHelp", git_resolve.show_help, {
	desc = "Show git-resolve-conflict help",
})
