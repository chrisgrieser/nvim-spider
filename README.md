<!-- LTeX: enabled=false -->
# nvim-spider 🕷️🕸️
<!-- LTeX: enabled=true -->
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-spider"><img alt="badge" src="https://dotfyle.com/plugins/chrisgrieser/nvim-spider/shield"/></a>

Use the `w`, `e`, `b` motions like a spider. Move by subwords and skip
insignificant punctuation.

<!-- toc -->

- [Features](#features)
	* [Subword motion](#subword-motion)
	* [Skipping insignificant punctuation](#skipping-insignificant-punctuation)
- [Installation](#installation)
- [Configuration](#configuration)
	* [Basic configuration](#basic-configuration)
	* [Advanced: custom movement patterns](#advanced-custom-movement-patterns)
- [Special cases](#special-cases)
	* [UTF-8 support](#utf-8-support)
	* [Subword text object](#subword-text-object)
	* [Operator-pending mode: the case of `cw`](#operator-pending-mode-the-case-of-cw)
	* [Consistent operator-pending mode](#consistent-operator-pending-mode)
	* [Motions in insert mode](#motions-in-insert-mode)
- [Credits](#credits)

<!-- tocstop -->

## Features
The `w`, `e`, `b` (and `ge`) motions work the same as the default ones by vim,
except for two differences:

### Subword motion
The motions are based on subwords, meaning they stop at the segments of a
`camelCase`, `SNAKE_CASE`, or `kebab-case` variable.

```lua
-- positions vim's `w` will move to
local myVariableName = FOO_BAR_BAZ
--    ^              ^ ^

-- positions spider's `w` will move to
local myVariableName = FOO_BAR_BAZ
--    ^ ^       ^    ^ ^   ^   ^
```

### Skipping insignificant punctuation
A sequence of one or more punctuation characters is considered significant if it
is surrounded by whitespace and does not include any non-punctuation characters.

```lua
foo == bar .. "baz"
--  ^      ^    significant punctuation

foo:find("a")
-- ^    ^  ^  insignificant punctuation
```

This speeds up the movement across the line by reducing the number of mostly
unnecessary stops.

```lua
-- positions vim's `w` will move to
if foo:find("%d") and foo == bar then print("[foo] has" .. bar) end
-- ^  ^^   ^  ^^  ^   ^   ^  ^   ^    ^    ^  ^  ^ ^  ^ ^  ^  ^ ^  -> 21

-- positions spider's `w` will move to
if foo:find("%d") and foo == bar then print("[foo] has" .. bar) end
-- ^   ^      ^   ^   ^   ^  ^   ^    ^       ^    ^    ^  ^    ^  -> 14
```

If you prefer to use this plugin only for subword motions, you can disable this
feature by setting `skipInsignificantPunctuation = false` in the `.setup()`
call.

> [!NOTE]
> This plugin ignores vim's `iskeyword` option.

## Installation

```lua
-- packer
use { "chrisgrieser/nvim-spider" }

-- lazy.nvim
{ "chrisgrieser/nvim-spider", lazy = true },

-- vim-plug
Plug("chrisgrieser/nvim-spider")
```

No keybindings are created by default. Below are the mappings to replace the
default `w`, `e`, and `b` motions with this plugin's version of them.

```lua
vim.keymap.set({ "n", "o", "x" }, "w", "<cmd>lua require('spider').motion('w')<CR>")
vim.keymap.set({ "n", "o", "x" }, "e", "<cmd>lua require('spider').motion('e')<CR>")
vim.keymap.set({ "n", "o", "x" }, "b", "<cmd>lua require('spider').motion('b')<CR>")

-- OR: lazy-load on keystroke (lazy.nvim)
{
	"chrisgrieser/nvim-spider",
	keys = {
		{ "w", "<cmd>lua require('spider').motion('w')<CR>", mode = { "n", "o", "x" } },
		{ "e", "<cmd>lua require('spider').motion('e')<CR>", mode = { "n", "o", "x" } },
		{ "b", "<cmd>lua require('spider').motion('b')<CR>", mode = { "n", "o", "x" } },
	},
},
```

> [!NOTE]
> For dot-repeat to work, you have to call the motions as Ex-commands.
> Dot-repeat will not work when using `function() require("spider").motion("w")
> end` as third argument.

## Configuration

### Basic configuration
The `.setup()` call is optional.

```lua
-- default values
require("spider").setup {
	skipInsignificantPunctuation = true,
	consistentOperatorPending = false, -- see the README for details
	subwordMovement = true,
	customPatterns = {}, -- see the README for details
}
```

You can also pass this configuration table to the `motion` function:

```lua
require("spider").motion("w", { skipInsignificantPunctuation = false })
```

Any options passed to `.motion` take precedence over the options set in
`.setup`.

### Advanced: custom movement patterns
You can use the `customPatterns` table to define custom movement patterns.
- These must be [lua
  patterns](https://www.lua.org/manual/5.4/manual.html#6.4.1).
- If multiple patterns are given, the motion searches for all of them and stops
  at the closest one. When there is no match, the search continues in the next
  line.
- The `customPatterns` option overrides `nvim-spider`'s default behavior,
  meaning no subword movement and skipping of punctuation. Pass a `pattern`
  table and set `overrideDefault = false` to extend `nvim-spider`'s default
  behavior with a new pattern.
- You can use `customPatterns` in the `.motion` call to create new motions,
  while still having access `nvim-spider`'s default behavior.
- They must be symmetrical (work the same backwards and forwards) to work for
  the backwards and forwards motions. If your patterns are not symmetric, you
  must define them for each direction via `.motion`.

A few examples:

```lua
-- The motion stops only at numbers.
require("spider").motion("w", {
	customPatterns = { "%d+" },
})

-- The motion stops at any occurrence of the ltters "A" or "C", in addition 
-- to spider's default behavior.
require("spider").motion("w", {
	customPatterns = {
		patterns = { "A", "C" },
		overrideDefault = false,
	},
})

-- The motion stops at the next declaration of a javascript variable.
-- (The `e` motion combined with the `.` matching any character in
-- lua patterns ensures that you stop at beginning of the variable name.)
require("spider").motion("e", {
	customPatterns = { "const .", "let .", "var ." },
})
```

## Special cases

### UTF-8 support
For adding UTF-8 support for matching non-ASCII text, add `luautf8` as rocks.
You can do so directly in `packer.nvim` or via dependency on `nvim_rocks` in
`lazy.nvim`.

```lua
-- packer
{ "chrisgrieser/nvim-spider", rocks = "luautf8" }

-- lazy.nvim
{
    "chrisgrieser/nvim-spider",
    lazy = true,
    dependencies = {
    	"theHamsta/nvim_rocks",
    	build = "pip3 install --user hererocks && python3 -mhererocks . -j2.1.0-beta3 -r3.0.0 && cp nvim_rocks.lua lua",
    	config = function() require("nvim_rocks").ensure_installed("luautf8") end,
    },
},
```

### Subword text object
This plugin supports `w`, `e`, and `b` in operator-pending mode, but does not
include a subword variant of `iw`. For a version of `iw` that considers
camelCase, check out the `subword` text object of
[nvim-various-textobjs](https://github.com/chrisgrieser/nvim-various-textobjs).

<!-- vale Google.FirstPerson = NO -->
### Operator-pending mode: the case of `cw`
In operator pending mode, vim's `web` motions are actually a bit inconsistent.
For instance, `cw` will change to the *end* of a word instead of the start of
the next word, like `dw` does. This is probably done for convenience in `vi`'s
early days before <!-- harper: ignore -->there were text objects. In my view,
this is quite problematic since it makes people habitualize inconsistent motion
behavior.

In this plugin, such small inconsistencies are therefore deliberately not
implemented. Apart from the inconsistency, such a behavior can create unexpected
results when used in subwords or near punctuation. If you nevertheless prefer
that behavior, you can achieve that behavior by mapping `cw` to `ce`:

```lua
vim.keymap.set("o", "w", "<cmd>lua require('spider').motion('w')<CR>")
vim.keymap.set("n", "cw", "ce", { remap = true })

-- OR in one mapping
vim.keymap.set("n", "cw", "c<cmd>lua require('spider').motion('e')<CR>")
```

### Consistent operator-pending mode
Vim has more inconsistencies related to how the motion range is interpreted (see
`:h exclusive`). For example, if the end of the motion is at the beginning of a
line, the endpoint is moved to the last character of the previous line.

```lua
foo bar
--  ^
baz
```

Typing `dw` deletes only `bar`. `baz` stays on the next line.

Similarly, if the start of the motion is before or at the first non-blank
character in a line, and the end is at the beginning of a line, the motion is
changed to `linewise`.

```lua
    foo
--  ^
bar
```

Typing `yw` yanks `foo\r`, that is, the indentation before the cursor is
included, and the register type is set to `linewise`.

Setting `consistentOperatorPending = true` removes these special cases. In the
first example, `bar\r` would be deleted charwise. In the second example, `foo\r`
would be yanked charwise.

**Caveats**
1. Last visual selection marks (`` `[ `` and `` `] ``) are updated and point to
   the endpoints of the motion. This was not always the case before.
2. Forced blockwise motion may be canceled if it cannot be correctly represented
   with the current `selection` option.

### Motions in insert mode
Simple and pragmatic: Wrap the normal mode motions in `<Esc>l` and `i`. (Drop
the `l` on backwards motions.)

```lua
vim.keymap.set("i", "<C-f>", "<Esc>l<cmd>lua require('spider').motion('w')<CR>i")
vim.keymap.set("i", "<C-b>", "<Esc><cmd>lua require('spider').motion('b')<CR>i")
```

## Credits
**Thanks**
- `@vypxl` and `@ii14` [for figuring out dot-repeatability of
  textobjects](https://github.com/chrisgrieser/nvim-spider/pull/4).
- `@vanaigr` for a large contribution regarding operator-pending mode.

**About the developer**  
In my day job, I am a sociologist studying the social mechanisms underlying the
digital economy. For my PhD project, I investigate the governance of the app
economy and how software ecosystems manage the tension between innovation and
compatibility. If you are interested in this subject, feel free to get in touch.

- [Website](https://chris-grieser.de/)
- [Mastodon](https://pkm.social/@pseudometa)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

<a href='https://ko-fi.com/Y8Y86SQ91' target='_blank'><img height='36'
style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3'
border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
