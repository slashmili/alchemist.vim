function! asyncomplete#sources#elixir#completor(opt, ctx) abort
    let l:num = a:ctx['lnum']
    let l:col = a:ctx['col']
    let l:file = a:ctx['filepath']

    let l:tempfile = s:write_buffer_to_tempfile(a:ctx)
    let l:cmd = [ 'sh', '-c', g:alchemist#alchemist_client . ' -d' . expand('%:p:h') . ' -l' . l:num . ' -c' . l:col . ' -r suggestions'  . ' < "' . l:tempfile . '"' ]


    let l:params = { 'stdout_buffer': '', 'file': l:tempfile}

    let l:jobid = async#job#start(l:cmd, {
			    \ 'on_stdout': function('s:handler', [a:opt, a:ctx, l:params]),
			    \ 'on_stderr': function('s:handler', [a:opt, a:ctx, l:params]),
			    \ 'on_exit': function('s:handler', [a:opt, a:ctx, l:params]),
			    \ })

    call asyncomplete#log(l:cmd, l:jobid, l:tempfile)

    if l:jobid <= 0
	    call delete(l:tempfile)
    endif
endfunction

function! s:handler(opt, ctx, params, id, data, event) abort
    if a:event ==? 'stdout'
        let a:params['stdout_buffer'] = a:params['stdout_buffer'] . join(a:data, "\n")
    elseif a:event ==? 'exit'
	let l:typed = a:ctx['typed']
        if a:data == 0
		let suggestions = split(a:params['stdout_buffer'], '\n')
		let l:matches = []
		for sugg in suggestions
			let details = matchlist(sugg, 'kind:\(.*\), word:\(.*\), abbr:\(.*\), menu:\(.*\), info:\(.*\)$')
			if len(details) > 0
				let info = substitute(s:strip(details[5]) , '<n>', '\n', "g")
				if details[1] == 'f'
					let word = details[2]
					let sug_parts = split(l:typed, '\.')
					let is_it_only_func = matchstr(l:typed, '\C^[a-z].*') != ''
					if len(sug_parts) == 1 && l:typed[len(l:typed) -1] != '.' && is_it_only_func == 1
						let word_parts = split(word, '\.')
						let word_size = len(word_parts) - 1
						let word = word_parts[word_size]
					endif
					let a = {'kind': details[1], 'word': word, 'abbr': details[3], 'menu': details[4], 'dup': 1, 'info': info}
				elseif details[1] == 'm' || details[1] == 'p' || details[1] == 'e' || details[1] == 's'
					let word = details[2]
					let a = {'kind': details[1], 'word': word, 'menu': details[4], 'abbr': details[3], 'info': info}
				endif

				call add(l:matches, a)
			endif
		endfor
		let l:col = a:ctx['col']
		let l:kw = matchstr(l:typed, '\v\S+$')
		let l:kwlen = len(l:kw)
		let l:startcol = l:col - l:kwlen
		echom l:startcol

		call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, l:matches)
	endif
        call delete(a:params['file'])
    elseif a:event ==? 'stdout'
        call asyncomplete#log(a:data)
    endif
endfunction

function! s:write_buffer_to_tempfile(ctx) abort
	let l:lines = getline(1, '$')
	let l:file = tempname()
	call writefile(l:lines, l:file)
	return l:file
endfunction

function! s:strip(input_string)
	return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction
