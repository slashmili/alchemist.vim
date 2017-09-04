if !exists('g:alchemist#alchemist_client')
    let g:alchemist#alchemist_client = expand("<sfile>:p:h:h") . '/../elixir_sense_client'
endif


function! elixircomplete#ex_doc_complete(ArgLead, CmdLine, CursorPos, ...)
  let suggestions = elixircomplete#get_suggestions(a:ArgLead, 1, len(a:ArgLead) + 1, [a:ArgLead . "\n"])
  if type(suggestions) != type([])
    return []
  endif
  return map(suggestions, 's:strip_dot(v:val.word)')
endfunction

function! s:strip_dot(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\.*$', '\1', '')
endfunction

function! s:strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! elixircomplete#auto_complete(findstart, base_or_suggestions)
    let cnum = col('.')
    if a:findstart
        return s:find_start()
    end
    let lnum = line('.')
    let cnum = col('.') + len(a:base_or_suggestions)
    let blines = getline(1, lnum -1)
    let cline = getline('.')
    let before_c = strpart(getline('.'), 0, col('.'))
    let after_c = strpart(getline('.'), col('.'), len(getline('.')))
    let cline = before_c . a:base_or_suggestions . after_c
    let alines = getline(lnum +1 , '$')
    let lines = blines + [cline] + alines
    "Handle YouCompleteMe cases
    if getline(lnum, lnum +1)[0] =~ a:base_or_suggestions . '$'
        let cnum = col('.') + len(a:base_or_suggestions)
        let lines = getline(1, '$')
    endif
    let suggestions = elixircomplete#get_suggestions(a:base_or_suggestions, lnum, cnum, lines)
    if len(suggestions) == 0
        return -1
    endif
    return suggestions
endfunction

" Omni findstart phase.
function! s:find_start()
    " return int 0 < n <= col('.')
    "
    " if the column left of us is whitespace, or [(){}[]]
    " no word
    let col = col('.')
    " get the column to the left of us
    if strpart(getline(line('.')), col-2, 1) =~ '[{}()         ]'
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


function! elixircomplete#get_suggestions(base_or_suggestions, lnum, cnum, lines)
    let req = 'suggestions'
    let result = alchemist#alchemist_client(req, a:lnum, a:cnum, a:lines)
    let suggestions = split(result, '\n')
    let parsed_suggestion = []
    for sugg in suggestions
        let details = matchlist(sugg, 'kind:\(.*\), word:\(.*\), abbr:\(.*\), menu:\(.*\), info:\(.*\)$')
        if len(details) > 0
            if details[1] == 'f'
                let word = details[2]
                let sug_parts = split(a:base_or_suggestions, '\.')
                let is_it_only_func = matchstr(a:base_or_suggestions, '\C^[a-z].*') != ''
                if len(sug_parts) == 1 && a:base_or_suggestions[len(a:base_or_suggestions) -1] != '.' && is_it_only_func == 1
                    let word_parts = split(word, '\.')
                    let word_size = len(word_parts) - 1
                    let word = word_parts[word_size]
                endif
                let a = {'kind': details[1], 'word': word, 'abbr': details[3], 'menu': details[4], 'dup': 1}
            elseif details[1] == 'm' || details[1] == 'p' || details[1] == 'e' || details[1] == 's'
                let word = details[2]
                let a = {'kind': details[1], 'word':  word, 'menu': details[4], 'abbr': details[3]}
            endif

            if exists('g:alchemist#extended_autocomplete') && g:alchemist#extended_autocomplete == 1
                let info = substitute(s:strip(details[5]) , '<n>', '\n', "g")
                let a.info = info
            endif
            call add(parsed_suggestion, a)
        endif
    endfor
    return parsed_suggestion
endfunction
