if exists("b:did_ftplugin_alchemist")
    finish
endif

let b:did_ftplugin_alchemist = 1

if !exists('g:alchemist#alchemist_client')
    let g:alchemist#alchemist_client = expand("<sfile>:p:h:h") . '/../alchemist_client'
endif

if !exists('g:alchemist#root')
    let g:alchemist#root = getcwd()
end

if !executable(g:alchemist#alchemist_client)
    finish
endif

if !exists('g:alchemist#omnifunc')
    let g:alchemist#omnifunc = 1
endif

if exists('&omnifunc') && g:alchemist#omnifunc
  setl omnifunc=elixircomplete#Complete
endif

nnoremap K :call alchemist#lookup_name_under_cursor()<CR>
command! -nargs=? ExDoc call alchemist#exdoc(<f-args>)
