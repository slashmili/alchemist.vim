syntax match ExDocHeading /\v^*.+$/
syntax match ExDocSection /\v^#+.+$/
syntax match ExDocQuoted  /`.\{-}`/
syntax match ExDocCode    /\v^\s{4}.+$/

syntax region ExDocListItem start=/\v^\s{2}\*/ end=/\v^\s*$/ contains=ExDocQuoted

highlight ExDocHeading guifg=#edddb6 gui=bold ctermfg=223 cterm=bold
highlight ExDocSection guifg=#edddb6 gui=bold ctermfg=223 cterm=bold
highlight ExDocQuoted  guifg=#97d2d5 ctermfg=195
highlight ExDocCode    guifg=#97d2d5 ctermfg=195
highlight link ExDocListItem Normal
