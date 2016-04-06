let s:buf_nr = -1
let s:module_match = '[A-Za-z0-9\._]\+'
let s:module_func_match = '[A-Za-z0-9\._?!]\+'

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
    return query
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
    let query = ''
    if empty(a:000)
        let query = alchemist#lookup_name_under_cursor()
    else
        let query = a:000[0]
    endif
    call s:open_doc_window(query, "new", "split")
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
