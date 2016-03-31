if !exists('g:alchemist#alchemist_client')
    let g:alchemist#alchemist_client = expand("<sfile>:p:h:h") . '/../alchemist_client'
endif


let s:elixir_namespace= '\<[A-Z][[:alnum:]]\+\(\.[A-Z][[:alnum:].]\+\)*.*$'
let s:erlang_module= ':\<'
let s:elixir_fun_w_arity = '.*/[0-9]$'
let s:elixir_module = '[A-Z][[:alnum:]_]\+\([A_Z][[:alnum:]_]+\)*'

function! elixircomplete#Complete(findstart, base_or_suggestions)
    if a:findstart
        return s:FindStart()
    else
        return s:build_completions(a:base_or_suggestions)
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
    set isk+=:
    let pos = searchpos('\<', 'bnW', line('.'))[1] - 1
    let &isk = l:isk_bak
    echo pos
    return pos
endfunction


function! s:build_completions(base_or_suggestions)
    if type(a:base_or_suggestions) == type([])
      let suggestions = a:base_or_suggestions
    else
      let suggestions = elixircomplete#get_suggestions(a:base_or_suggestions)
    endif

    if len(suggestions) == 0
        return -1
    elseif len(suggestions) == 1
        return suggestions
    elseif len(suggestions) > 1
        let [ newbase ; tail ] = suggestions
        if newbase =~ '.*\.$'
            " case Li^X^O should offer "List." as the first completion
            return map(suggestions, 's:parse_suggestion(newbase, v:val)')
        end
        return map(tail, 's:parse_suggestion(newbase, v:val)')
    endif
endfunction

function! s:parse_suggestion(base, suggestion)
    if a:suggestion =~ s:elixir_fun_w_arity
        let word = strpart(a:suggestion, 0, match(a:suggestion, '/[0-9]\+$'))
        if a:base =~ '.*\.$'
            " case: Li^X^O => base: "List." word: "first" ===> List.first
            return {'word': a:base . word, 'abbr': a:suggestion, 'kind': 'f' }
        else
            let ch = split(a:base, '\.')
            if len(ch) == 1
                " case: g^X^O => base "get_" word: "get_in" ===> get_in
                return {'word': word, 'abbr': a:suggestion, 'kind': 'f' }
            endif
            " case: List.f^X^O => base "List.f" word: "first" ===> List.first
            let func_fqn = join(ch[:(len(ch)-2)], ".") . "." . word
            "echom "base: " . a:base . ", word: " . word . ", sugg: " . a:suggestion
            return {'word': func_fqn, 'abbr': a:suggestion, 'kind': 'f' }
        endif
    elseif a:base =~ s:erlang_module
        echom 'base: ' . a:base . ', sug: ' . a:suggestion
        if a:suggestion[0] == ":"
            " case: :gen.^X^O => base ":gen." ==> :gen.
            return {'word': a:suggestion, 'abbr': a:suggestion, 'kind': 'm'}
        endif
        return {'word': ':'.a:suggestion, 'abbr': a:suggestion, 'kind': 'm'}
    elseif a:suggestion =~ s:elixir_module
        if a:base == a:suggestion
            " case: Li^X^O => base: "List." suggestion: "List." ==> List.
            return {'word': a:suggestion, 'abbr': a:suggestion, 'kind': 'm'}
        endif
        if a:base =~ '\.$'
            " case: Li^X^O => base: "List." suggestion: "Chars" ==> List.Chars.
            return {'word': a:base.a:suggestion.'.', 'abbr': a:suggestion, 'kind': 'm'}
        endif
        " case: L^X^O => base: "L" suggestion: "List" ==> List
        return {'word': a:suggestion.'.', 'abbr': a:suggestion, 'kind': 'm'}
    else
        return {'word': a:suggestion, 'abbr': a:suggestion }
    endif
endfunction


function! elixircomplete#get_suggestions(hint)
    let req = alchemist#alchemist_format("COMP", a:hint, "Elixir", [], [])
    let result = alchemist#alchemist_client(req)
    return filter(split(result, '\n'), 'v:val != "END-OF-COMP"')
endfunction
