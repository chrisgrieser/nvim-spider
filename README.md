<!-- LTeX: enabled=false -->
# nvim-spider 🕷️🕸️
<!-- LTeX: enabled=true -->
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-spider">
<img alt="badge" src="https://dotfyle.com/plugins/chrisgrieser/nvim-spider/shield"/></a>

Use the `w`, `e`, `b` motions like a spider. Move by subwords and skip
insignificant punctuation.

A lua implementation of
[CamelCaseMotion](https://github.com/bkad/CamelCaseMotion), with extra
consideration of punctuation. Works in normal, visual, and operator-pending
mode. Supports counts and dot-repeat.

<!-- toc -->

- [Features](#features)
	* [Subword Motion](#subword-motion)
	* [Skipping Insignificant Punctuation](#skipping-insignificant-punctuation)
- [Installation](#installation)
- [Configuration](#configuration)
	* [Advanced: Custom Movement Patterns](#advanced-custom-movement-patterns)
- [Special Cases](#special-cases)
	* [UTF-8 support](#utf-8-support)
	* [Subword Text Object](#subword-text-object)
	* [Operator-pending Mode: The case of `cw`](#operator-pending-mode-the-case-of-cw)
	* [Consistent Operator-pending Mode](#consistent-operator-pending-mode)
	* [Motions in Insert Mode](#motions-in-insert-mode)
- [Credits](#credits)
- [About the devleoper](#about-the-developer)

<!-- tocstop -->

## Features
The `w`, `e`, `b` (and `ge`) motions work the same as the default ones by vim,
except for two differences:

### Subword Motion
The movements happen by subwords, meaning it stops at the sub-parts of a
camelCase, SCREAMING_SNAKE_CASE, or kebab-case variable.

```lua
-- positions vim's `w` will move to
local myVariableName = FOO_BAR_BAZ
--    ^              ^ ^

-- positions spider's `w` will move to
local myVariableName = FOO_BAR_BAZ
--    ^ ^       ^    ^ ^   ^   ^
```

### Skipping Insignificant Punctuation
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
```

No keybindings are created by default. Below are the mappings to replace the
default `w`, `e`, and `b` motions with this plugin's version of them.

```lua
vim.keymap.set(
	{ "n", "o", "x" },
	"w",
	"<cmd>lua require('spider').motion('w')<CR>",
	{ desc = "Spider-w" }
)
vim.keymap.set(
	{ "n", "o", "x" },
	"e",
	"<cmd>lua require('spider').motion('e')<CR>",
	{ desc = "Spider-e" }
)
vim.keymap.set(
	{ "n", "o", "x" },
	"b",
	"<cmd>lua require('spider').motion('b')<CR>",
	{ desc = "Spider-b" }
)

-- OR: lazy-load on keystroke
-- lazy.nvim
{
	"chrisgrieser/nvim-spider",
	keys = {
		{
			"e",
			"<cmd>lua require('spider').motion('e')<CR>",
			mode = { "n", "o", "x" },
		},
		-- ...
	},
},
```

<!-- vale Google.Will = NO -->
> [!NOTE]
> For dot-repeat to work, you have to call the motions as Ex-commands. When
> using `function() require("spider").motion("w") end` as third argument of
> the keymap, dot-repeatability will not work.

## Configuration
The `.setup()` call is optional.

```lua
-- default values
require("spider").setup {
	skipInsignificantPunctuation = true,
	consistentOperatorPending = false, -- see "Consistent Operator-pending Mode" in the README
	subwordMovement = true,
	customPatterns = {}, -- check "Custom Movement Patterns" in the README for details
}
```

You can also pass this configuration table to the `motion` function:

```lua
require("spider").motion("w", { skipInsignificantPunctuation = false })
```

Any options passed here will be used, and override the options set in the
`setup()` call.

### Advanced: Custom Movement Patterns
You can use the `customPatterns` table to define custom movement patterns. These
must be [lua patterns](https://www.lua.org/manual/5.4/manual.html#6.4.1), and
they must be symmetrical (work the same backwards and forwards) to work
correctly with `b` and `ge`. If multiple patterns are given, the motion
searches for all of them and stops at the closest one. When there is no match, the
search continues in the next line.

If you have interesting ideas for custom patterns, please share them in the
[GitHub discussions](./discussions), or make a PR to add them as built-in
options.

A few examples:

```lua
-- The motion stops only at numbers.
require("spider").motion("w", {
	customPatterns = { "%d+" },
})

-- The motion stops at only at words with at least 3 chars or at any punctuation.
-- (Lua patterns have no quantifier like `{3,}`, thus the repetition.)
require("spider").motion("w", {
	customPatterns = { "%w%w%w+", "%p+" },
})

-- The motion stops only at hashes like `ef82a2`, avoiding repetition by using
-- `string.rep()`.
-- Extend default patterns by passing a `patterns` table and
-- setting `overrideDefault` to false.
require("spider").motion("w", {
	customPatterns = {
		patterns = {
			("%x"):rep(6) .. "+" },
		},
		overrideDefault = false,
	},
})

-- The motion stops at the next declaration of a variable in -- javascript.
-- (The `e` motion combined with the `.` matching any character in
-- lua patterns ensures that you stop at beginning of the variable name.)
require("spider").motion("e", {
	customPatterns = { "const .", "let .", "var ." },
})
```

> [!NOTE]
> The `customPatterns` option overrides `nvim-spider`'s default behavior, meaning subword
> movement and skipping of punctuation are disabled. You can add
> `customPatterns` as an option to the `.motion` call to create new motions,
> while still having access `nvim-spider`'s default behavior.
> Pass a patterns table and set overrideDefault to false to extend
> `nvim-spider`'s default behavior with a new pattern.

## Special Cases

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

### Subword Text Object
This plugin supports `w`, `e`, and `b` in operator-pending mode, but does not
include a subword variant of `iw`. For a version of `iw` that considers
camelCase, check out the `subword` text object of
[nvim-various-textobjs](https://github.com/chrisgrieser/nvim-various-textobjs).

<!-- vale Google.FirstPerson = NO -->
### Operator-pending Mode: The case of `cw`
In operator pending mode, vim's `web` motions are actually a bit inconsistent.
For instance, `cw` will change to the *end* of a word instead of the start of
the next word, like `dw` does. This is probably done for convenience in vi's
early days before there were text objects. In my view, this is quite problematic
since it makes people habitualize inconsistent motion behavior.

In this plugin, such small inconsistencies are therefore deliberately not
implemented. Apart from the inconsistency, such a behavior can create unexpected
results when used in subwords or near punctuation. If you nevertheless want to,
you can achieve that behavior by mapping `cw` to `ce`:

```lua
vim.keymap.set("o", "w", "<cmd>lua require('spider').motion('w')<CR>")
vim.keymap.set("n", "cw", "ce", { remap = true })

-- or the same in one mapping without `remap = true`
vim.keymap.set("n", "cw", "c<cmd>lua require('spider').motion('e')<CR>")
```

### Consistent Operator-pending Mode
Vim has more inconsistencies related to how the motion range is
interpreted (see `:h exclusive`). For example, if the end of the motion is at
the beginning of a line, the endpoint is moved to the last character of the previous line.

```
foo bar
--- ^
baz
```

Typing `dw` deletes only `bar`. `baz` stays on the next line.

Similarly, if the start of the motion is before or at the first non-blank
character in a line, and the end is at the beginning of a line, the motion
is changed to linewise.

```
    foo
--- ^
bar
```

Typing `yw` yanks `    foo\r`, i.e. the indentation before the cursor is included,
and the register type is set to linewise.

Setting `consistentOperatorPending = true` removes these special cases. In the
first example, `bar\r` would be deleted charwise. In the second example, `foo\r` would
be yanked charwise.

Caveats:
1. Last visual selection marks (`` `[ `` and `` `] ``) are updated
   and point to the endpoints of the motion. This was not always the case before.
2. Forced blockwise motion may be cancelled if it cannot be correctly
   represented with the current `selection` option.

### Motions in Insert Mode

Simple and pragmatic: Wrap the normal mode motions in `<Esc>l` and `i`. (Drop
the `l` on backwards motions.)

```lua
vim.keymap.set("i", "<C-f>", "<Esc>l<cmd>lua require('spider').motion('w')<CR>i")
vim.keymap.set("i", "<C-b>", "<Esc><cmd>lua require('spider').motion('b')<CR>i")
```

## Credits
Thanks to `@vypxl` and `@ii14` [for figuring out dot-repeatability](https://github.com/chrisgrieser/nvim-spider/pull/4).

## About the developer
In my day job, I am a sociologist studying the social mechanisms underlying the
digital economy. For my PhD project, I investigate the governance of the app
economy and how software ecosystems manage the tension between innovation and
compatibility. If you are interested in this subject, feel free to get in touch.

I also occasionally blog about vim: [Nano Tips for Vim](https://nanotipsforvim.prose.sh)

- [Academic Website](https://chris-grieser.de/)
- [Mastodon](https://pkm.social/@pseudometa)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

<a href='https://ko-fi.com/Y8Y86SQ91' target='_blank'><img
	height='36'
	style='border:0px;height:36px;'
	src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3'
	border='0'
	alt='Buy Me a Coffee at ko-fi.com'
/></a>
