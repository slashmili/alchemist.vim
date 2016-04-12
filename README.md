# alchemist.vim

<img src="https://github.com/slashmili/alchemist.vim/raw/master/logo.png" width="200" align="right">

[![License GPL 3](https://img.shields.io/badge/license-GPL_3-green.svg)](http://www.gnu.org/licenses/gpl-3.0)
[![Build Status](https://travis-ci.org/slashmili/alchemist.vim.svg?branch=develop)](https://travis-ci.org/slashmili/alchemist.vim)
[![Stories in Ready](https://badge.waffle.io/slashmili/alchemist.vim.png?label=ready&title=Ready)](http://waffle.io/slashmili/alchemist.vim)



**NOTE** : This is an experimental project and needs extra features in *alchemist-server* which is on going disucssion in this [PR](https://github.com/tonini/alchemist-server/pull/8). I used the clone of *alchemist-server* in this project

This plugin uses [alchemist-server](https://github.com/tonini/alchemist-server) to give inside about your elixir project in vim.

**alchemist.vim** supports:

* Completion for Modules and functions.
* Documentation lookup for Modules and functions.
* Jump to the definition.

[More supports will come soon](https://github.com/slashmili/alchemist.vim/issues/1)

## Dependencies

You need these dependencies on the same machine you run vim

* **Elixir** > v1.0.4 to run alchemist-server
* **Python** `alchemist_client` is the script that talks to _alchemist-server_
* **AnsiEsc** (optional) to show documents in color in vim otherwise documents will be shown as _markdown_

## Installation

You can use your favourite VIM plugin mannger for installation, in this doc we use [Vundle](https://github.com/VundleVim/Vundle.vim)

Add this line to your `.vimrc`
```
Plugin 'slashmili/alchemist.vim'
```

To show the documents in color you need [AnsiEsc](https://github.com/powerman/vim-plugin-AnsiEsc) plugin as well
```
Plugin 'powerman/vim-plugin-AnsiEsc'
```

## Usage
Go to your elixir project directory and run `vim`

### Shortkeys:

  * Auto completion: `<C-x><C-o>` while your are in `INSERT` mode.
  * Documention: Press `K` while cursor is under a module or function in `NORMAL` mode.
  * Jump to the definition: Press `<C-]>` while cursor is under the keyword in `NORMAL` mode.
  * Jump through tag stack: Press `<C-T>` to jump between tag stack in `NORMAL` mode.

### Commands:

  * ExDoc: `ExDoc [module/function]` provides document (press TAB to get autocomplete).
  * Mix: `Mix [command]` run mix command (press TAB to get commands autocomplete). If you already have an existing `Mix` command, alchemist won't define this command.
  * ExDef: `ExDef [module/function]` jumps to the definition.

### Demo

#### Vanilla vim
<a href="https://asciinema.org/a/e23f0el00vlg0s5z9nrwp6kba"><img src="https://asciinema.org/a/e23f0el00vlg0s5z9nrwp6kba.png" height="400"></a>

##### Autocomplete with deoplete
<a href="https://asciinema.org/a/9uupb79bp90p9ji4jbfolvzuk"><img src="https://asciinema.org/a/9uupb79bp90p9ji4jbfolvzuk.png" height="300"></a>

## Issues

If you faced any problem, create a new issue [in the issue tracker](https://github.com/slashmili/alchemist.vim/issues).

## Contributing

Fork the project and help to add new feauters to the project. Don't know what to contribute? Take a look at the project [todo list](https://github.com/slashmili/alchemist.vim/issues/1)

Remember all interactions on our repositories follow elixir's [Code of Conduct](https://github.com/elixir-lang/elixir/blob/master/CODE_OF_CONDUCT.md).
