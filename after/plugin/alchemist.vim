let s:buf_nr = -1

function! alchemist#alchemist_client(req)
    let req = a:req . "\n"
    return system(g:alchemist#alchemist_client.  ' -d ' . g:alchemist#root, req)
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
    return a:cmd. " { \"" . a:arg . "\", [ context: ". a:context.
                          \ ", imports: ". string(a:imports).
                          \ ", aliases: ". string(a:aliases) . "] }"
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
    "ex. Enum.map(&Guard.execute(&1)) < wont work for help on Guard.execute
    let query = substitute(expand("<cWORD>"), '[.,;}]$', '', '')
    let query = substitute(query, '(.*$', '', '')
    "looking for module doc if cursor is on name of module
    let word = expand("<cword>")
    let query = strpart(query, 0, match(query, word . '\C')) . word

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
        else
            set ft=markdown
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
    %delete _
    call append(0, split(content, "\n"))
    sil $delete _
    sil $delete _
    AnsiEsc!
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
