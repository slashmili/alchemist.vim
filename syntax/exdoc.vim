syntax match ExDocHeading /\v^*.+$/
syntax match ExDocSection /\v^#+.+$/
syntax match ExDocQuoted  /`.\{-}`/
syntax match ExDocCode    /\v^\s{4}.+$/

syntax region ExDocListItem start=/\v^\s{2}\*/ end=/\v^\s*$/ contains=ExDocQuoted

highlight link ExDocHeading Keyword
highlight link ExDocSection Keyword
highlight link ExDocQuoted  Identifier
highlight link ExDocCode    Identifier
highlight link ExDocListItem Normal
