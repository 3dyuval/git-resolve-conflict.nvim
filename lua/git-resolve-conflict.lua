-- Git Resolve Conflict Plugin
-- Pure Lua implementation of git conflict resolution (no external dependencies)
-- Recreates git-resolve-conflict logic using native git commands

local M = {}

-- Get file path, handling diffview buffers
local function get_file_path()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return nil, "No file in current buffer"
  end

  -- Handle diffview buffers
  if file:match("^diffview://") then
    -- Extract real file path from diffview buffer name
    local real_file = file:gsub("^diffview://[^/]+/[^/]+/", "")
    if real_file and real_file ~= "" then
      local git_root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
      if vim.v.shell_error == 0 then
        file = git_root .. "/" .. real_file
      end
    end
  end

  return file
end

-- Check if file is in conflicted state
local function is_conflicted(file)
  local file_dir = vim.fn.fnamemodify(file, ":h")
  local git_root = vim.fn
    .system("cd " .. vim.fn.shellescape(file_dir) .. " && git rev-parse --show-toplevel")
    :gsub("\n", "")

  if vim.v.shell_error ~= 0 then
    return false, "Not in a git repository"
  end

  local relative_file = file:gsub("^" .. vim.pesc(git_root) .. "/", "")
  local cmd = string.format(
    "cd %s && git diff --name-only --diff-filter=U | grep -Fxq %s",
    vim.fn.shellescape(git_root),
    vim.fn.shellescape(relative_file)
  )

  vim.fn.system(cmd)
  return vim.v.shell_error == 0, relative_file, git_root
end

-- Pure Lua implementation of git-resolve-conflict
-- Based on: git merge-file --ours/--theirs/--union -p ./tmp.ours ./tmp.common ./tmp.theirs
function M.resolve_file(strategy)
  local file, err = get_file_path()
  if not file then
    vim.notify(err or "Unable to get file path", vim.log.levels.WARN)
    return false
  end

  local conflicted, relative_file, git_root = is_conflicted(file)
  if not conflicted then
    vim.notify("File is not in conflicted state: " .. (relative_file or file), vim.log.levels.INFO)
    return false
  end

  -- Create temporary files (same logic as original bash script)
  local temp_files = {
    common = os.tmpname(),
    ours = os.tmpname(),
    theirs = os.tmpname(),
  }

  local success = false
  local conflicts_resolved = 0

  local merge_strategy = "--" .. strategy
  local merge_cmd
  local add_cmd
  local conflict_count
  local output

  -- Execute git commands to extract conflict versions
  local commands = {
    string.format(
      "cd %s && git show :1:%s > %s",
      vim.fn.shellescape(git_root),
      vim.fn.shellescape(relative_file),
      temp_files.common
    ),
    string.format(
      "cd %s && git show :2:%s > %s",
      vim.fn.shellescape(git_root),
      vim.fn.shellescape(relative_file),
      temp_files.ours
    ),
    string.format(
      "cd %s && git show :3:%s > %s",
      vim.fn.shellescape(git_root),
      vim.fn.shellescape(relative_file),
      temp_files.theirs
    ),
  }

  -- Extract conflict versions
  for _, cmd in ipairs(commands) do
    if vim.fn.system(cmd) ~= "" and vim.v.shell_error ~= 0 then
      vim.notify("Failed to extract conflict versions", vim.log.levels.ERROR)
      goto cleanup
    end
  end

  -- Run git merge-file with strategy
  merge_cmd = string.format(
    "git merge-file %s -p %s %s %s > %s",
    merge_strategy,
    vim.fn.shellescape(temp_files.ours),
    vim.fn.shellescape(temp_files.common),
    vim.fn.shellescape(temp_files.theirs),
    vim.fn.shellescape(file)
  )

  output = vim.fn.system(merge_cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("git merge-file failed: " .. output, vim.log.levels.ERROR)
    goto cleanup
  end

  -- Stage the resolved file
  add_cmd = string.format(
    "cd %s && git add %s",
    vim.fn.shellescape(git_root),
    vim.fn.shellescape(relative_file)
  )
  if vim.fn.system(add_cmd) ~= "" and vim.v.shell_error ~= 0 then
    vim.notify("Failed to stage resolved file", vim.log.levels.ERROR)
    goto cleanup
  end

  -- Count resolved conflicts (approximate)
  conflict_count = output and tostring(output):gsub("[^\n]", ""):len() or 0
  conflicts_resolved = math.max(1, math.floor(conflict_count / 3)) -- Rough estimate

  success = true
  vim.cmd("checktime")
  vim.notify(
    string.format("Resolved %d conflicts with '%s' strategy", conflicts_resolved, strategy),
    vim.log.levels.INFO
  )

  ::cleanup::
  -- Clean up temporary files
  for _, temp_file in pairs(temp_files) do
    os.remove(temp_file)
  end

  return success
end

-- Show picker for strategy selection
function M.pick_and_resolve()
  local choices = {
    "Union (merge both changes)",
    "Ours (keep our changes)",
    "Theirs (keep their changes)",
  }

  vim.ui.select(choices, {
    prompt = "Resolve all conflicts in file:",
  }, function(choice, idx)
    if not choice then
      return
    end

    local strategies = { "union", "ours", "theirs" }
    M.resolve_file(strategies[idx])
  end)
end

-- Utility functions for diffview integration
function M.resolve_ours()
  return M.resolve_file("ours")
end
function M.resolve_theirs()
  return M.resolve_file("theirs")
end
function M.resolve_union()
  return M.resolve_file("union")
end

-- Show help/usage information
function M.show_help()
  local help_text = [[
Git Resolve Conflict Plugin (Pure Lua Implementation)

Available functions:
  - resolve_file(strategy): Resolve file with strategy ("ours"|"theirs"|"union")
  - pick_and_resolve(): Show picker to select strategy
  - resolve_ours(): Quick resolve with ours strategy
  - resolve_theirs(): Quick resolve with theirs strategy  
  - resolve_union(): Quick resolve with union strategy

No external dependencies required!
Uses native git commands: git show, git merge-file, git add

Usage in diffview.lua:
  local git_resolve = require("git-resolve-conflict")
  
  { "n", "<leader>gO", git_resolve.resolve_ours, { desc = "Resolve file: ours" } }
  { "n", "<leader>gT", git_resolve.resolve_theirs, { desc = "Resolve file: theirs" } }
  { "n", "<leader>gU", git_resolve.resolve_union, { desc = "Resolve file: union" } }
  { "n", "<leader>gr", git_resolve.pick_and_resolve, { desc = "Resolve file: pick" } }
]]

  vim.notify(help_text, vim.log.levels.INFO)
end

return M
