let s:buf_nr = -1
let s:module_match = '[:A-Za-z0-9\._]\+'
let s:module_func_match = '[A-Za-z0-9\._?!]\+'
let g:alchemist_tag_stack = []
let g:alchemist_tag_stack_is_used = 0

if !exists('g:alchemist#alchemist_client')
    let g:alchemist#alchemist_client = expand("<sfile>:p:h:h") . '/../elixir_sense_client'
endif

function! alchemist#alchemist_client(req, lnum, cnum, lines)
    let req = a:req
    let cmd = g:alchemist#alchemist_client
    if exists('g:alchemist#elixir_erlang_src')
        let cmd = cmd . ' -o ' . g:alchemist#elixir_erlang_src
    endif
    let cmd = cmd . ' -d "' . expand('%:p:h') . '"'
    let cmd = cmd . ' --line=' . a:lnum
    let cmd = cmd . ' --column=' . a:cnum
    let cmd = cmd . ' --request=' . a:req
    let result =  system(cmd, join(a:lines, "\n"))
    if len(matchlist(result, '^error:')) > 0
        call s:echo_error('alchemist.vim: failed with message ' . result)
        return ''
    endif
    return result
endfunction

function! alchemist#get_doc(word)
    if a:word == ''
        let lnum = line('.')
        let cnum = col('.')
        let lines = getline(1, '$')
    else
        let lnum = 1
        let cnum = len(a:word)
        let lines = [a:word . "\n"]
    endif
    if match(a:word, "^:") ==# 0
        " strip `:` and function name since erlang offers man pages on the
        " module only
        " eg. translate `:gen_server.cast()` into `gen_server`
        let query = strpart(a:word, 1)
        let query = split(query, '\.')[0]
        return alchemist#get_doc_erl(query)
    endif
    return alchemist#get_doc_ex(lnum, cnum, lines)
endfunction

function! alchemist#get_doc_ex(lnum, cnum, lines)
    let result = alchemist#alchemist_client('docs', a:lnum, a:cnum, a:lines)

    " fix heading colors
    let result = substitute(result, '\e\[7m\e\[33m', '[1m[33m', 'g')
    " fix code example colors
    let result = substitute(result, '\e\[36m\e\[1m', '[1m[36m', 'g')
    return result
endfunction

function! alchemist#get_doc_erl(word)
    return system("erl -man " . shellescape(a:word))
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
    "replace key: to key,
    let aliases_str = substitute(aliases_str, ": ", ', ', 'g')

    return a:cmd. " { \"" . a:arg . "\", [ context: ". a:context.
                          \ ", imports: ". imports_str .
                          \ ", aliases: ". aliases_str . "] }"
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
    let elixir_erlang_module_func_match = ':\?' . s:module_func_match
    let before_match = matchlist(before_cursor, elixir_erlang_module_func_match . '$')
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
    return query
endfunction

function! s:open_doc_window(query, newposition, position)
    let content = alchemist#get_doc(a:query)

    let lines = split(content, '\n')
    if len(lines) < 2
        redraw
        echo "Alchemist: No matches for '" . a:query . "'!"
        return
    endif

    " reuse existing buffer window if it exists otherwise create a new one
    if !bufexists(s:buf_nr)
        execute a:newposition
        sil file `="[ExDoc]"`
        let s:buf_nr = bufnr('%')
        if !exists('g:alchemist_mappings_disable')
            if !exists('g:alchemist_keyword_map') | let g:alchemist_keyword_map = 'K' | en
            exe 'nnoremap <buffer> <silent> ' . g:alchemist_keyword_map . ' :call alchemist#exdoc()<CR>'
        endif
    elseif bufwinnr(s:buf_nr) == -1
        execute a:position
        execute s:buf_nr . 'buffer'
    elseif bufwinnr(s:buf_nr) != bufwinnr('%')
        execute bufwinnr(s:buf_nr) . 'wincmd w'
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
    setlocal noreadonly
    %delete _
    call append(0, split(content, "\n"))
    sil $delete _
    sil $delete _
    normal gg

    if match(a:query, "^:") ==# 0
        setlocal ft=man
    else
        setlocal nomodifiable
        setlocal ft=exdoc
    endif

    noremap <silent> <buffer> q :call <SID>close_doc_win()<cr>
endfunction

function! s:close_doc_win()
    close!
endfunction

function! alchemist#exdoc(...)
    let query = ''
    if empty(a:000)
        let name = alchemist#lookup_name_under_cursor()
        if match(name, "^:") ==# 0
            let query = name
        else
            let query = ''
        end
    else
        let query = a:000[0]
    endif
    call s:open_doc_window(query, "new", "split")
endfunction

function! alchemist#exdef(...)
    let query = ''
    if empty(a:000)
        let query = alchemist#lookup_name_under_cursor()
        let lnum = line('.')
        let cnum = col('.')
        let lines = getline(1, '$')
    else
        let lnum = 1
        let cnum = len(a:000[0])
        let lines = [a:000[0]]
        let query = a:000[0]
    endif
    if s:strip(query) == ''
        call s:echo_error('E426: tag not found: ')
        return
    endif

    let result = alchemist#alchemist_client('definition', lnum, cnum, lines)
    let source_match = split(result, '\n')
    if len(source_match) == 0 || source_match[0] == 'non_existing:0'
        call s:echo_error('E426: tag not found: ' . query)
        return
    endif
    let source_file = source_match[0]
    let line = 1
    let source_and_line = matchlist(source_file, '\(.*\):\([0-9]\+\)')
    if len(source_and_line) > 0
        let source_file = source_and_line[1]
        let line = source_and_line[2]
    endif

    let compile_basepath = get(g:, 'alchemist_compile_basepath', getcwd())
    let compile_basepath = substitute(compile_basepath, "/*$", "/", "")

    let rel_path = substitute(source_file, compile_basepath, '', '')
    if !filereadable(rel_path)
        call s:echo_error("E484: Can't open file: " . rel_path)
        return
    endif
    call add(g:alchemist_tag_stack, [bufnr('%'), line('.'), col('.')])
    if matchlist(rel_path, 'deps/') != []
        execute 'view ' . rel_path
    else
        execute 'e ' . rel_path
    endif
    execute line
endfunction

function! alchemist#jump_tag_stack()
    if len(g:alchemist_tag_stack) == 0
        if g:alchemist_tag_stack_is_used == 1
            call s:echo_error('E555: at bottom of tag stack')
            return
        endif
        call s:echo_error('E73: tag stack empty')
        return
    endif
    let stack_size = len(g:alchemist_tag_stack)
    let stack_item = remove(g:alchemist_tag_stack, stack_size - 1)
    let buf_nr = stack_item[0]
    if bufexists(stack_item[0])
        execute stack_item[0] . 'buffer'
        call cursor(stack_item[1], stack_item[2])
    end
    let g:alchemist_tag_stack_is_used = 1
endfunction

function! s:strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:echo_error(text)
    echohl ErrorMsg
    echo a:text
    echohl None
endfunction

function! alchemist#get_current_module_details()
    " matchit exists and vim-elixir is loaded with correct settings
    let can_trust_matchit = exists("g:loaded_matchit") && &l:indentexpr == "elixir#indent()"
    let def_module_match = '\s*defmodule\s\+\(' . s:module_match . '\)'
    let lines = reverse(getline(1, line('.')))
    let matched_line = line('.')
    let original_line = matched_line
    let result = {'module' : {}, 'aliases': [], 'imports': []}

    let aliases_in_multi_lines = 0
    let multi_lines = ''

    for l in lines
        let module = alchemist#get_module_name(l)
        if module != {} && can_trust_matchit
          " validate that we really reached intended module
          " and not got fooled by nested modules

          let first_line = matched_line

          " Save cursor position
          let l:save = winsaveview()
          " Try to use matchit to find module's 'end' keyword
          call cursor(first_line, 1)
          call search(def_module_match . ".*do", 'ceW', first_line)
          normal %
          let last_line = line('.')
          " Move cursor to original position
          call winrestview(l:save)

          " ignore module if original line is not in its range
          if (original_line <= first_line || original_line >= last_line)
            let module = {}
          endif
        endif
        if module != {}
            let module.line = matched_line
            let result.module =  module
            "we reached the top of the module
            return result
        endif

        if match(l, '{') < 0 && match(l, '}') >0
            let aliases_in_multi_lines = 1
            let multi_lines = ''
        endif
        if aliases_in_multi_lines == 1
            let multi_lines =  l . multi_lines
            if match(l, '{') >= 0
                let aliases_in_multi_lines = 0
                if match(l, '^\s*alias\s\+') >= 0
                    let aliases = alchemist#get_aliases(multi_lines)
                    if aliases != []
                        let result.aliases += aliases
                    endif
                endif
                let multi_lines = ''
            endif
        else
            let aliases = alchemist#get_aliases(l)
            if aliases != []
                let result.aliases += aliases
            endif
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

function! alchemist#findMixDirectory() "{{{
    let fName = expand("%:p:h")

    while 1
        let mixFileName = fName . "/mix.exs"
        if file_readable(mixFileName)
            return fName
        endif

        let fNameNew = fnamemodify(fName, ":h")
        " after we reached top of heirarchy
        if fNameNew == fName
            return ''
        endif
        let fName = fNameNew
    endwhile
endfunction "}}}

function! alchemist#mix(...)
  let mixDir = alchemist#findMixDirectory()

  let old_cwd = getcwd()
  if mixDir != ''
    execute 'lcd ' . fnameescape(mixDir)
  endif

  exe '!mix ' . join(copy(a:000), ' ')

  execute 'lcd ' . fnameescape(old_cwd)
endfunction

function! alchemist#mix_complete(ArgLead, CmdLine, CursorPos, ...)
  if !exists('g:mix_tasks')
    let mixDir = alchemist#findMixDirectory()

    let old_cwd = getcwd()
    if mixDir != ''
      execute 'lcd ' . fnameescape(mixDir)
    endif

    let g:mix_tasks = system("mix -h | awk '!/-S/ && $2 != \"#\" { print $2 }'")

    execute 'lcd ' . fnameescape(old_cwd)
  endif
  return g:mix_tasks
endfunction

command! -nargs=? -complete=customlist,elixircomplete#ex_doc_complete ExDoc
      \ call alchemist#exdoc(<f-args>)

command! -nargs=? -complete=customlist,elixircomplete#ex_doc_complete ExDef
      \ call alchemist#exdef(<f-args>)

if !exists(':Mix')
  command! -bar -nargs=? -complete=custom,alchemist#mix_complete Mix
        \ call alchemist#mix(<q-args>)
endif

command! -nargs=* -complete=customlist,elixircomplete#ex_doc_complete IEx
      \ call alchemist#open_iex(<q-args>)
command! -nargs=0 IExHide call alchemist#hide_iex()
