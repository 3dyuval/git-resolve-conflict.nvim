# git-resolve-conflict.nvim

> Resolve merge conflict from Neovim, in one file, using given strategy (--ours, --theirs, --union)
>
>     :GitResolve ours
>     :GitResolve theirs  
>     :GitResolve union
>
>     lua require("git-resolve-conflict").resolve_ours()
>     lua require("git-resolve-conflict").resolve_theirs()
>     lua require("git-resolve-conflict").resolve_union()

## Why would you need it

To be able to resolve certain well-defined types of merge conflicts, without opening mergetool.

This is particularly useful in automated merge workflows, or if you have large number of well-defined merges to resolve directly from your editor.

Unlike external tools, this plugin integrates seamlessly with Neovim and works especially well with diffview.nvim for visual conflict resolution.

## Things to be aware of

Note though, this is just a dumb text-based merge resolution; if you're unlucky, the merged file might be syntactically incorrect.

For example: when using `ours` strategy on `package.json` where both sides added an entry at the end of `dependencies` or `scripts` array, the result will be two blocks added without trailing comma between them (hence invalid JSON).

## Installation

### With lazy.nvim

```lua
{
  "3dyuval/git-resolve-conflict.nvim",
  dependencies = { "sindrets/diffview.nvim" },
  cmd = { "GitResolve", "GitResolveHelp" },
}
```

### With packer.nvim

```lua
use {
  "3dyuval/git-resolve-conflict.nvim",
  requires = { "sindrets/diffview.nvim" },
  cmd = { "GitResolve", "GitResolveHelp" },
}
```

## Usage

### Commands

- `:GitResolve` - Interactive picker to choose strategy
- `:GitResolve ours` - Resolve using 'ours' strategy  
- `:GitResolve theirs` - Resolve using 'theirs' strategy
- `:GitResolve union` - Resolve using 'union' strategy
- `:GitResolveHelp` - Show help information

### Lua API

```lua
local git_resolve = require("git-resolve-conflict")

-- Interactive picker
git_resolve.pick_and_resolve()

-- Direct resolution
git_resolve.resolve_ours()
git_resolve.resolve_theirs() 
git_resolve.resolve_union()

-- Generic resolution
git_resolve.resolve_file("ours")    -- or "theirs", "union"
```

### Integration with diffview.nvim

Add keymaps to your diffview configuration:

```lua
return {
  "sindrets/diffview.nvim",
  dependencies = { "3dyuval/git-resolve-conflict.nvim" },
  config = function()
    require("diffview").setup({
      keymaps = {
        view = {
          -- File-wide conflict resolution
          { "n", "<leader>gO", function() require("git-resolve-conflict").resolve_ours() end, { desc = "Resolve file: OURS" } },
          { "n", "<leader>gT", function() require("git-resolve-conflict").resolve_theirs() end, { desc = "Resolve file: THEIRS" } },
          { "n", "<leader>gU", function() require("git-resolve-conflict").resolve_union() end, { desc = "Resolve file: UNION" } },
          { "n", "<leader>gr", function() require("git-resolve-conflict").pick_and_resolve() end, { desc = "Resolve file: pick strategy" } },
        },
      },
    })
  end,
}
```

## FAQ

- **Q: Why no updates in N years?**
- A: Because it's feature-complete.

- **Q: Does it work on Windows?**
- A: Yes, but requires git and a unix-y shell environment (WSL, Git Bash, etc.).

- **Q: How is this different from the original git-resolve-conflict?**
- A: This is a pure Lua implementation for Neovim. No external dependencies, integrates directly with your editor and diffview.nvim.

## TL;DR

It's a Neovim plugin wrapper around [git-merge-file](https://git-scm.com/docs/git-merge-file) to simplify the API and integrate with your editor workflow.

It's better than `git merge -Xours` because that would resolve conflicts for all files. Here we can resolve conflict for just one file.

It's better than `git checkout --ours package.json` because that would lose changes from `theirs` even if they are not conflicted. Here we can resolve conflict using a three-way merge and keep the non-conflicted changes from both sides.

## Description

Say you have multiple git branches and you want to merge between them, and always resolve conflicts **in a particular file** with a **fixed strategy** (say `ours`).

For instance, you have `master` (stable) and `develop` (unstable) branches. When code is stable you freeze the `master`, and development continues in `develop`, which is merged to `master` every few weeks.

But then you find bugs at regression testing stage, you fix them in `master`, and you build. In the meantime, you also build `develop` separately. Each build bumps `version` field in `package.json`.

Since those branches can be built separately, a file like `package.json` will be modified in both branches, and there'll be a merge conflict due to `version` field being changed in both branches.

How to easily **resolve the merge conflict** in an **automated manner** from within your editor in such a situation?

## Git built-ins that do not solve the problem

- `git merge -Xours`: that would resolve *ALL conflicts* in *ALL files* using the same strategy. This might be too much. (For instance, you might want to have an automatic merging script, which can do a successful conflict resolution only if `foobar.json` is *the only file that was modified*; on any other files modified, the merge should fail)

- `git checkout --ours filename.txt`: that would **discard ALL the changes** from `theirs` version, which is brutal. There might be some valid, non-conflicting changes that would be discarded this way.

- What we need is something like `git-resolve-conflict --ours filename.txt`

**This is what this Neovim plugin provides, with editor integration.**

## Credits

Based on the original [git-resolve-conflict](https://github.com/jakub-g/git-resolve-conflict) by [jakub-g](https://github.com/jakub-g). Reimplemented in pure Lua for Neovim with no external dependencies.