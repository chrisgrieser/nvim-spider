<!-- LTeX: enabled=false -->
# nvim-spider 🕷️🕸️
<!-- LTeX: enabled=true -->
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-spider">
<img src="https://dotfyle.com/plugins/chrisgrieser/nvim-spider/shield" /></a>

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
- [Subword Text Object](#subword-text-object)
- [Notes on Operator-pending Mode](#notes-on-operator-pending-mode)
- [Credits](#credits)

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

> __Note__  
> This plugin ignores vim's `iskeyword` option.

## Installation

```lua
-- packer
use { "chrisgrieser/nvim-spider" }

-- lazy.nvim
{
	"chrisgrieser/nvim-spider",
	keys = {
		{ -- example for lazy-loading on keystroke
			"e",
			"<cmd>lua require('spider').motion('e')<CR>",
			mode = { "n", "o", "x" },
		},
	},
},
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
```
<!-- vale Google.Will = NO -->
> __Note__  
> For dot-repeat to work, you have to call the motions as Ex-commands. When
> calling `function() require("spider").motion("w") end` as third argument of
> the keymap, dot-repeatability will *not* work.

## Configuration
The `.setup()` call is optional. Currently, its only option is to disable the
skipping of insignificant punctuation:

```lua
-- default values
require("spider").setup {
	skipInsignificantPunctuation = true,
	subwordMovement = true,
}
```

You can also pass this configuration table to the `motion` function:

```lua
require("spider").motion("w", { skipInsignificantPunctuation = false })
```

Any options passed here will be used, and override the options set in the
`setup()` call.

## Subword Text Object
This plugin supports `w`, `e`, and `b` in operator-pending mode, but does not
include a subword variant of `iw`. For a version of `iw` that considers
camelCase, check out the `subword` text object of
[nvim-various-textobjs](https://github.com/chrisgrieser/nvim-various-textobjs).

<!-- vale Google.FirstPerson = NO -->
## Notes on Operator-pending Mode
In operator pending mode, vim's `web` motions are actually a bit inconsistent.
For instance, `cw` will change to the *end* of a word instead of the start of
the next word, like `dw` does. This is probably done for convenience in vi's
early days before there were text objects. In my view, this is quite problematic
since it makes people habitualize inconsistent motion behavior.

In this plugin, such small inconsistencies are therefore deliberately not
implemented. Apart from the inconsistency, such a behavior can create unexpected
results when used in subwords or near punctuation. If you absolutely want to,
you can map `cw` to `ce` though. (Remember to add `remap = true` as option for
the keymap.)

## Credits
__Thanks__  
To `@vypxl` and `@ii14` [for figuring out dot-repeatability](https://github.com/chrisgrieser/nvim-spider/pull/4).

__About Me__  
In my day job, I am a sociologist studying the social mechanisms underlying the
digital economy. For my PhD project, I investigate the governance of the app
economy and how software ecosystems manage the tension between innovation and
compatibility. If you are interested in this subject, feel free to get in touch.

__Blog__  
I also occasionally blog about vim: [Nano Tips for Vim](https://nanotipsforvim.prose.sh)

__Profiles__  
- [reddit](https://www.reddit.com/user/pseudometapseudo)
- [Discord](https://discordapp.com/users/462774483044794368/)
- [Academic Website](https://chris-grieser.de/)
- [Twitter](https://twitter.com/pseudo_meta)
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
