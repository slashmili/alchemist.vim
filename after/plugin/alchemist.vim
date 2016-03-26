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
    let query = substitute(expand("<cWORD>"), '[.,;]$', '', '')
    let query = substitute(query, '(.*$', '', '')
    let query = substitute(query, '</\?tt>', '', 'g')
    call s:display_doc(query)
endfunction

function! s:display_doc(query)
    let doc = alchemist#get_doc(a:query)
    "TODO: find a way without creating tmp file
    let fileName = a:query.".ansi"
    let cacheFile = substitute('/tmp/'.fileName, '#', ',','')
    let lines = filter(split(doc, '\n'), 'v:val != "END, func_puts-OF-DOCL"')
    let lines = filter(lines, 'v:val !~ "Could not load module*"')
    if len(lines) == 0
        redraw
        echom "No matches!"
    else
        call s:focusBrowserWindow()
        call writefile(lines, fnameescape(cacheFile))
        exec "edit ".fnameescape(fnameescape(cacheFile))
        call s:prepareDocBuffer()
    endif
endfunction

function! s:focusBrowserWindow()
    if !exists("s:browser_bufnr")
        rightbelow split
        return
    endif
    if bufwinnr(s:browser_bufnr) == winnr()
        return
    end
    let winnr = bufwinnr(s:browser_bufnr)
    if winnr == -1
        " create window
        rightbelow split
    else
        exec winnr . "wincmd w"
    endif
endfunction

function! s:prepareDocBuffer()
    setlocal nowrap
    setlocal textwidth=0
    noremap <buffer> q :call <SID>close_doc_win()<cr>
    setlocal statusline="%<%f\ %r%=%-14.(%l,%c%V%)\ %P"


    let s:browser_bufnr = bufnr('%')
    call s:syntaxLoad()
    setlocal nomodifiable
endfunction

func! s:syntaxLoad()
    if !exists("g:syntax_on")
        setlocal modifiable
        silent! %!sed -e 's/<\/\?tt>/`/g' -e 's/<\/\?em>//g' -e 's/<\/\?b>//g' -e 's/<\/\?i>//g'
        setlocal nomodifiable
        write
        return
    endif

    "TODO: prevent toggling AnsiEsc
    if alchemist#ansi_enabled()
        AnsiEsc
    endif
endfunction

function! s:close_doc_win()
    close!
endfunction
