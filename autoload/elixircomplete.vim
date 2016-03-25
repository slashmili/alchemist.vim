if !exists('g:alchemist#alchemist_client')
    let g:alchemist#alchemist_client = expand("<sfile>:p:h:h") . '/../alchemist_client'
endif


let s:elixir_namespace= '\<[A-Z][[:alnum:]]\+\(\.[A-Z][[:alnum:].]\+\)*.*$'
let s:erlang_module= ':\<'
let s:elixir_fun_w_arity = '.*/[0-9]$'
let s:elixir_module = '[A-Z][[:alnum:]_]\+\([A_Z][[:alnum:]_]+\)*'


function! elixircomplete#Complete(findstart, base)
    if a:findstart
        return s:FindStart()
    else
        return s:build_completions(a:base)
    endif
endfunction

" Omni findstart phase.
function! s:FindStart()
    " return int 0 < n <= col('.')
    "
    " if the column left of us is whitespace, or [(){}[]]
    " no word
    let col = col('.')
    " get the column to the left of us
    if strpart(getline(line('.')), col-2, 1) =~ '[{}() 	]'
        return col - 1
    endif
    " TODO This is a pretty dirty way to go about this
    " but it does seem to work for now.
    let l:isk_bak = &isk
    set isk+=.
    let pos = searchpos('\<', 'bnW', line('.'))[1] - 1
    let &isk = l:isk_bak
    echo pos
    return pos
endfunction

function! s:build_completions(base)
    let suggestions = elixircomplete#get_suggestions(a:base)
    if len(suggestions) == 0
        return -1
    elseif len(suggestions) == 1
        return suggestions
    elseif len(suggestions) > 1
        let [ newbase ; tail ] = suggestions
        if newbase !~ '.*\.$' " non-unique match
            let newbase = strpart(newbase, 0, match(newbase, '[^.]\+$'))
        endif
        return map(tail, 's:parse_suggestion(newbase, v:val)')
    endif
endfunction

function! s:parse_suggestion(base, suggestion)
    "echom "base: " . a:base . " | suggestion:" . a:suggestion
    if a:suggestion =~ s:elixir_fun_w_arity
        let word = strpart(a:suggestion, 0, match(a:suggestion, '/[0-9]\+$'))
        return {'word': a:base . word, 'abbr': a:suggestion, 'kind': 'f' }
    elseif a:suggestion =~ s:elixir_module
        return {'word': a:base.a:suggestion.'.', 'abbr': a:suggestion, 'kind': 'm'}
    elseif a:suggestion =~ s:erlang_module
        return {'word': ':'.a:suggestion, 'abbr': a:suggestion, 'kind': 'm'}
    else
        return {'word': a:suggestion, 'abbr': a:suggestion }
    endif
endfunction


function! elixircomplete#get_suggestions(hint)
    let req = s:alchemist_format("COMP", a:hint, "Elixir", [], [])  . "\n"
    let result = system(g:alchemist#alchemist_client. ' -t COMP -d /Users/milad/dev/elide -a /Users/milad/dev/alchemist-server/run.exs', req)
    return filter(split(result, '\n'), 'v:val != "END-OF-COMP"')
endfunction

function! s:alchemist_format(cmd, arg, context, imports, aliases)
    " context: Module
    " imports: List(Module)
    " aliases: List({Alias, Module})
    return a:cmd. " { \"" . a:arg . "\", [ context: ". a:context.
                          \ ", imports: ". string(a:imports).
                          \ ", aliases: ". string(a:aliases) . "] }"
endfunction
