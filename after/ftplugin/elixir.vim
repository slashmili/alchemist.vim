if exists("b:did_ftplugin_kimya")
    finish
endif

let b:did_ftplugin_kimya = 1

if !exists('g:kimya#alchemist_client')
    let g:kimya#alchemist_client = expand("<sfile>:p:h:h") . '/../alchemist/client/run.exs'
endif

if !exists('g:kimya#root')
    let g:kimya#root = getcwd()
end


if !executable(g:kimya#alchemist_client)
    finish
endif

if !exists('g:kimya#omnifunc')
    let g:kimya#omnifunc = 1
endif

if exists('&omnifunc') && g:kimya#omnifunc
  setl omnifunc=elixircomplete#Complete
endif
