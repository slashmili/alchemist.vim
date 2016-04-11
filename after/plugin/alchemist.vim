let s:buf_nr = -1
let s:module_match = '[A-Za-z0-9\._]\+'
let s:module_func_match = '[A-Za-z0-9\._?!]\+'

if !exists('g:alchemist#alchemist_client')
    let g:alchemist#alchemist_client = expand("<sfile>:p:h:h") . '/../alchemist_client'
endif

if !exists('g:alchemist#root')
    let g:alchemist#root = getcwd()
end

function! alchemist#alchemist_client(req)
    let req = a:req . "\n"
    let ansi = ""
    if !alchemist#ansi_enabled()
        let ansi = '--colors=false'
    endif
    return system(g:alchemist#alchemist_client. ' ' . ansi  . ' -d ' . g:alchemist#root, req)
endfunction

function! alchemist#get_doc(word)
    let req = alchemist#alchemist_format("DOCL", a:word, "Elixir", [], [])
    let result = alchemist#alchemist_client(req)
    return result
endfunction

function! alchemist#alchemist_format(cmd, arg, context, imports, aliases)
    " context: Module
    " imports: List(Module)
    " aliases: List({Alias, Module})
    let current_module = alchemist#get_current_module_details()
    let aliases_str = string(a:aliases)
    if aliases_str == "[]"
        let aliases_str = string(current_module.aliases)
    endif
    let imports_str = string(a:imports)
    if imports_str == "[]"
        if current_module.module != {}
            let current_module.imports += [current_module.module.name]
        endif
        let imports_str = string(current_module.imports)
    endif
    "remove '
    let aliases_str = substitute(aliases_str, "'", '', 'g')
    let imports_str = substitute(imports_str, "'", '', 'g')
    "replace : to ,
    let aliases_str = substitute(aliases_str, ":", ',', 'g')

    return a:cmd. " { \"" . a:arg . "\", [ context: ". a:context.
                          \ ", imports: ". imports_str .
                          \ ", aliases: ". aliases_str . "] }"
endfunction

function! alchemist#ansi_enabled()
    if exists(':AnsiEsc')
        return 1
    endif
    return 0
endfunction

function! alchemist#lookup_name_under_cursor()
    "looking for full function/module string
    "ex. OptionParse.parse
    "ex. GenServer
    "ex. List.Chars.Atom
    "ex. {:ok, Map.new}
    "ex. Enum.map(&Guard.execute(&1))
    "ex. Enum.all?(&(&1.valid?))

    let before_cursor = strpart(getline('.'), 0, col('.'))
    let after_cursor = strpart(getline('.'), col('.'))
    let before_match = matchlist(before_cursor, s:module_func_match . '$')
    let after_match = matchlist(after_cursor, '^' . s:module_func_match)
    let query = ''
    let before = ''
    if len(before_match) > 0
        let before = before_match[0]
    endif
    let after = ''
    if len(after_match) > 0
        let after = after_match[0]
    endif
    if before =~ '\.$'
        "case before = List.Chars. after = to_char_list
        let query = substitute(before, '[.]$', '', '')
    elseif after =~ '^\.'
        "case before = List.Chars  after = .to_char_list
        let query = before
    elseif after =~ '.*\.'
        "case before = OptionParse after = r.parse
        "case before = Mix.Shel    after = l.IO.cmd
        let up_to_dot = matchlist(after, '\([A-Za-z0-9_]\+\)\.')
        let query = before . up_to_dot[1]
    else
        let query = before . after
    endif
    call s:open_doc_window(query, 'new', 'split')
endfunction

function! s:open_doc_window(query, newposition, position)
    let content = alchemist#get_doc(a:query)

    let lines = split(content, '\n')
    if len(lines) < 3
        redraw
        echom "No matches for '" . a:query . "'!"
        return
    endif

    " reuse existing buffer window if it exists otherwise create a new one
    if !bufexists(s:buf_nr)
        execute a:newposition
        sil file `="[ExDoc]"`
        let s:buf_nr = bufnr('%')
        if alchemist#ansi_enabled()
            AnsiEsc
        endif
    elseif bufwinnr(s:buf_nr) == -1
        execute a:position
        execute s:buf_nr . 'buffer'
    elseif bufwinnr(s:buf_nr) != bufwinnr('%')
        execute bufwinnr(s:buf_nr) . 'wincmd w'
    endif

    if !alchemist#ansi_enabled()
        setlocal ft=markdown
    endif

    setlocal bufhidden=delete
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nocursorline
    setlocal nocursorcolumn
    setlocal iskeyword+=:
    setlocal iskeyword-=-

    setlocal modifiable
    %delete _
    call append(0, split(content, "\n"))
    sil $delete _
    sil $delete _
    if alchemist#ansi_enabled()
        AnsiEsc!
    endif
    normal gg
    setlocal nomodifiable
    noremap <silent> <buffer> q :call <SID>close_doc_win()<cr>
endfunction

function! s:close_doc_win()
    close!
endfunction

function! alchemist#exdoc(...)
    if empty(a:000)
        call alchemist#lookup_name_under_cursor()
        return
    endif
    call s:open_doc_window(a:000[0], "new", "split")
endfunction

function! s:strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! alchemist#get_current_module_details()
    let def_module_match = '\s*defmodule\s\+\(' . s:module_match . '\)'
    let lines = reverse(getline(1, line('.')))
    let matched_line = line('.')
    let result = {'module' : {}, 'aliases': [], 'imports': []}
    for l in lines
        let module = alchemist#get_module_name(l)
        if module != {}
            let module.line = matched_line
            let result.module =  module
            "we reached the top of the module
            return result
        endif
        let aliases = alchemist#get_aliases(l)
        if aliases != []
            let result.aliases += aliases
        endif
        let import = alchemist#get_import(l)
        if import != ''
            let result.imports += [import]
        endif
        let matched_line = matched_line - 1
    endfor
    return result
endfunction

function! alchemist#get_module_name(line)
    let def_module_match = '^\s\+defmodule\s\+\(' . s:module_match . '\)'
    let r = matchlist(a:line, def_module_match)
    if len(r) > 0
        return {'name': r[1], 'type': 'sub_module'}
    endif
    let def_module_match = '^\s*defmodule\s\+\(' . s:module_match . '\)'
    let r = matchlist(a:line, def_module_match)
    if len(r) > 0
        return {'name': r[1], 'type': 'main_module'}
    endif
    return {}
endfunction

function! alchemist#get_aliases(line)
    let module_sep_match = '[A-Za-z0-9\._,[:space:]]\+'
    let alias_match = '^\s*alias\s\+'
    let simple_match = alias_match . '\(' . s:module_match . '\)'
    let multiple_match = alias_match .'\(' . s:module_match . '\)\.{\(' . module_sep_match .'\)}'
    let as_match =  alias_match . '\(' . s:module_match . '\)\s*,\s*as:\s\+\(' . s:module_match . '\)'

    let r = matchlist(a:line, as_match)
    if len(r) > 0
        return [{r[2] : r[1]}]
    endif

    let r = matchlist(a:line, multiple_match)
    if len(r) > 0
        let base_module = r[1]
        let sub_modules = split(r[2], ",")
        let aliases = []
        for m in sub_modules
            let alias_name = split(m, '\.')[-1]
            let alias_name = s:strip(alias_name)
            let aliases +=  [{alias_name : s:strip(base_module) . '.' . s:strip(m)}]
        endfor
        return aliases
    endif

    let r = matchlist(a:line, simple_match)
    if len(r) > 0
        let base_module = r[1]
        let alias_name = split(base_module, '\.')[-1]
        return [{alias_name : base_module}]
    endif
    return []
endfunction

function! alchemist#get_import(line)
    let import_match = '^\s*import\s\+\(' . s:module_match . '\)'
    let r = matchlist(a:line, import_match)
    if len(r) > 1
        return r[1]
    end
    return ''
endfunction

" {{{ IEx

if !exists('g:alchemist_iex_term_size')
  let g:alchemist_iex_term_size = 15
endif
if !exists('g:alchemist_iex_term_split')
  let g:alchemist_iex_term_split = "split"
endif
if has('nvim')
  let s:alchemist_iex_runner = "terminal"
elseif exists('g:ConqueTerm_Loaded')
  let s:alchemist_iex_runner = "ConqueTerm"
endif

function! s:iex_open_cmd()
  return "botright " . g:alchemist_iex_term_size . g:alchemist_iex_term_split
endfunction

function! s:iex_buffer_exists()
  return exists('s:alchemist_iex_buffer') && bufexists(s:alchemist_iex_buffer)
endfunction

function! s:iex_enter_user_command(command, mode)
  if empty(a:command)
    startinsert
  else
    call feedkeys(a:mode. a:command . "\<CR>")
  endif
endfunction


function! alchemist#open_iex(command)
  if !exists('s:alchemist_iex_runner')
    echom "IEx requires either Neovim or ConqueShell"
    return ""
  endif
  if s:iex_buffer_exists()
    let winno = bufwinnr(s:alchemist_iex_buffer)
    " if IEx is the current buffer and no command was passed, hide it
    if s:alchemist_iex_buffer == bufnr("%") && empty(a:command)
      call alchemist#hide_iex()

    " if the buffer is in an open window, switch to it
    elseif winno != -1
      exec winno . "wincmd w"
      call s:iex_enter_user_command(a:command, 'i')

    " otherwise the buffer is hidden, open it in a new window
    else
      exec s:iex_open_cmd() . " +buffer" . s:alchemist_iex_buffer
      call s:iex_enter_user_command(a:command, 'i')
    endif
  else
    " no IEx buffer exists, open a new one
    exec s:iex_open_cmd()
    if filereadable('mix.exs')
      exec s:alchemist_iex_runner . " iex -S mix"
    else
      exec s:alchemist_iex_runner . " iex"
    endif
    let s:alchemist_iex_buffer = bufnr("%")
    call s:iex_enter_user_command(a:command, '')
  endif
endfunction

function! alchemist#hide_iex()
  if exists('s:alchemist_iex_runner') && exists('s:alchemist_iex_buffer')
    " only hide the window if it is open
    if bufwinnr(s:alchemist_iex_buffer) != -1
      " Neovim has :{winnr}hide whereas Vim doesn't
      if s:alchemist_iex_runner == 'terminal'
        exec bufwinnr(s:alchemist_iex_buffer) . "hide"
      else
        let current_window = winnr()
        exec bufwinnr(s:alchemist_iex_buffer) . "wincmd w"
        hide
        exec current_window . "wincmd w"
      endif
    endif
  endif
endfunction

" }}}

function! alchemist#mix(...)
  exe '!mix ' . join(copy(a:000), ' ')
endfunction

function! alchemist#mix_complete(ArgLead, CmdLine, CursorPos, ...)
  if !exists('g:mix_tasks')
    let g:mix_tasks = system("mix -h | awk '!/-S/ && $2 != \"#\" { print $2 }'")
  endif
  return g:mix_tasks
endfunction

command! -nargs=? -complete=customlist,elixircomplete#ExDocComplete ExDoc
      \ call alchemist#exdoc(<f-args>)

if !exists(':Mix')
  command! -buffer -bar -nargs=? -complete=custom,alchemist#mix_complete Mix
        \ call alchemist#mix(<q-args>)
endif

command! -nargs=* -complete=customlist,elixircomplete#ExDocComplete IEx
      \ call alchemist#open_iex(<q-args>)
command! -nargs=0 IExHide call alchemist#hide_iex()
