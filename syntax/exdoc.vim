syntax include @ELIXIR syntax/elixir.vim

syn match  ExDocHeading /\v^*.+$/ contains=ExDocHeadingMarker
syn match  ExDocHeadingMarker /\v^*/ contained
syn match  ExDocSection /\v^#+.+$/ contains=ExDocSectionMarker
syn match  ExDocSectionMarker /\v^#+/ contained
syn match  ExDocQuoted  /`.\{-}`/
syn match  ExDocCode /\v^\s{4}((iex)|(\.{3})\>)@!.*$/ contains=@ELIXIR
syn region ExDocListItem start=/\v^\s{2}\*/ end=/\v^\s*$/ contains=ExDocQuoted
" TODO, not working
" syn match  ExDocExample /\v^\s{4}((iex)|(\.{3})\>)@=.*$/ contains=ExDocIEx,@ELIXIR
" syn match  ExDocIEx /\v^\s{4}((iex)|(\.{3})\>)/ contained

hi def link ExDocHeading       Title
hi def link ExDocHeadingMarker Comment
hi def link ExDocSectionMarker Comment
hi def link ExDocSection       Title
hi def link ExDocQuoted        string
hi def link ExDocListItem      Normal
" hi def link ExDocIEx           Comment
