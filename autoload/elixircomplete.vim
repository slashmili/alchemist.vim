" This code partially is based on helpex.vim project
" Authors:
"  * sanmiguel <michael.coles@gmail.com>
"  * Milad

if !exists('g:alchemist#alchemist_client')
    let g:alchemist#alchemist_client = expand("<sfile>:p:h:h") . '/../alchemist_client'
endif


let s:elixir_namespace= '\<[A-Z][[:alnum:]]\+\(\.[A-Z][[:alnum:].]\+\)*.*$'
let s:erlang_module= ':\<'
let s:elixir_fun_w_arity = '.*/[0-9]$'
let s:elixir_module = '[A-Z][[:alnum:]_]\+\([A_Z][[:alnum:]_]+\)*'

function! elixircomplete#ExDocComplete(ArgLead, CmdLine, CursorPos, ...)
  let suggestions = elixircomplete#Complete(0, a:ArgLead)
  if type(suggestions) != type([])
    return []
  endif
  return map(suggestions, 's:strip_dot(v:val.word)')
endfunction

function! s:strip_dot(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\.*$', '\1', '')
endfunction

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
    endif
    return suggestions
endfunction

function! elixircomplete#get_suggestions(hint)
    let req = alchemist#alchemist_format("COMPX", a:hint, "Elixir", [], [])
    let result = alchemist#alchemist_client(req)
    let suggestions = filter(split(result, '\n'), 'v:val != "END-OF-COMPX"')
    let parsed_suggestion = []
    for sugg in suggestions
        let details = matchlist(sugg, 'kind:\(.*\), word:\(.*\), abbr:\(.*\)$')
        if len(details) > 0
            let a = {'kind': details[1], 'word': details[2], 'abbr': details[3]}
            call add(parsed_suggestion, a)
        endif
    endfor
    return parsed_suggestion
endfunction
