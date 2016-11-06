if exists("b:did_ftplugin_alchemist")
    finish
endif

let b:did_ftplugin_alchemist = 1

if !exists('g:alchemist#alchemist_client')
    let g:alchemist#alchemist_client = expand("<sfile>:p:h:h") . '/../alchemist_client'
endif

if !executable(g:alchemist#alchemist_client)
    finish
endif

if !exists('g:alchemist#omnifunc')
    let g:alchemist#omnifunc = 1
endif

if exists('&omnifunc') && g:alchemist#omnifunc
  setl omnifunc=elixircomplete#Complete
endif

runtime! ftplugin/man.vim
nnoremap <buffer> <silent> K :call alchemist#exdoc()<CR>

if !exists('g:alchemist_tag_disable')
    if !exists('g:alchemist_tag_map') | let g:alchemist_tag_map = '<C-]>' | en
    if !exists('g:alchemist_tag_stack_map') | let g:alchemist_tag_stack_map = '<C-T>' | en
    if g:alchemist_tag_map != '' && !hasmapto('alchemist#exdef()')
        exe 'nnoremap <buffer> <silent> ' . g:alchemist_tag_map . ' :call alchemist#exdef()<CR>'
    endif
    if g:alchemist_tag_stack_map != '' && !hasmapto('alchemist#jump_tag_stack()')
        exe 'nnoremap <buffer> <silent> ' . g:alchemist_tag_stack_map . ' :call alchemist#jump_tag_stack()<CR>'
    endif
endif
