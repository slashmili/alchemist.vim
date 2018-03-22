# Changelog

# Lithium(3.X.X)

## [3.1.0] - 2018-04-22
### Added
- Support python3
- Support for utf8 docs

### Changed
- Import ElixirSense client directly into deoplete plugin
- Enhancement on greedy regex

### Fixed
- Fix throwing error when looking up erlang docs in neovim #121
- Fix a problem that find a function's location

### Changed
- Move erlang terms test to python unittest

## [3.0.1] - 2017-10-31

### Changed

- Upgrade elixir sense to 1.0.1

## [3.0.0] - 2017-09-04

### Added
- Use [ElixirSense](https://github.com/msaraiva/elixir_sense) as IDE server
- Implement simple version of erl terms coder/decoder in python

### Changed

- Require OTP 19 and above to use unix socket
- Support ElixirSense request and response in vim script
- Support ElixirSense request and response in deoplete

### Removed
- Alchemist Server
- Jump to function definition on Elixir code and Projects that run in docker container(Still able to jump to Module file)

# Helium (2.X.X)

## v 2.8.2
	- Use hi link for exdoc syntax rather than explicit colors

## v 2.8.1
	- Deoplete remote plugin truncates the last completion

## v 2.8.0
	- Server listens using unix socket(security patch)

## v 2.7.1
	- Process Commands raises on unexpected input(security patch)

## v 2.7.0
	- Multiline alias support #46
	- Fix some error in Elixir 1.2
	- Allow disabling and redefining mapping #91
	- adds syntax highlights to ExDoc buffers when `!alchemist#ansi_enabled()`
	- use colours as opposed to highlight groups

## v 2.6.2
	- Allow to jump through navigation in ExDoc buffer #82

## v 2.6.1
	- Fix remote code execution vulnerability

## v 2.6.0
	  add g:alchemist_compile_basepath option #78

## v 2.5.0
	- show documentation for erlang modules #49
	- stop alchemist server being 10 min idle
	- Improve waiting time for alchemist_server to start
	- fix a bug related to running alchemist.vim for the first time #64

## v 2.4.0
	- Don't run alchemist server if it's already running on parent dir #48
	- Support for umbrella project #53

## v 2.3.2
	- fix mappings to be buffer local #58
	- add autocomplete to :ExDef command #50

## v 2.3.1
	- fix autocomplete #52

## v 2.3.0
	- updated alchemist server to the latest version

## v 2.2.1
	- Fix a bug in autocomplete <module>.<func> with only one match

## v 2.2.0
	- Python3 compatibility

## v 2.1.1
	- fix the ansi colors in ExDoc lookup

## v 2.1.0
	- implement ExDef to jump to the definition.
	- map CTRL-] to jump to the definition of the keyword under the cursor
	- map CTRL-T Jump to older entry in the tag stack.
	- support alias for erlang modules.
	- IEx Integration

## v 2.0.1
	- Mix command is available on all buffers (bugfix)

## v 2.0.0
	- use absolute path of project directory
	- detect project base dir based on running servers or locating mix.exs
	- move autocomplete rules to python client
	- set 10 seconds time while talking to alchemist server
	- add mix support in command-line mode(enabled if you don't have any other mix plugin)
	- auto complete for ExDoc in command-line mode


# Hydrogen (1.X.X)

## v 1.2.0
	- improvements on looking up for module/function name

## v 1.1.1
	- restore default min_pattern_length for deoplete

## v 1.1.0
	- added support for deoplete

## v 1.0.0
	- initial release
