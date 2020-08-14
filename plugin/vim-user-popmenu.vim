let g:user_menu = [
            \ [ "Save", #{ type: 'ex', body: ':w', opts: "only-in-insert,always-something" } ],
            \ [ "Toggle completion {g:vichord_summaric_completion_time}", #{ type: 'code', body: 'let g:vichord_search_in_let = 1 - g:vichord_search_in_let', opts: "only-in-normal" } ],
            \ [ "Open …", #{ type: 'ex', body: 'Ex', opts: "only-in-visual"} ],
            \ [ "← Other… →", #{ type: 'ex', body: 'Ex', opts: "always-show"} ]
            \ ]

" ·•« User Menu Plugin »•· ·•« zphere-zsh/vim-user-popmenu »•·
" Copyright (c) 2020 « Sebastian Gniazdowski ».
" License: « Gnu GPL v3 ».
" 
" Example user-menu «list» of «dictionaries»:
" 
" let g:user_menu = [
"     \ [ "Reload",      #{ type: "cmd",  body: ":ed" } ],
"     \ [ "Save",        #{ type: "cmd",  body: ":w!" } ],
"     \ [ "Load passwd", #{ type: "code", body: "tabe /etc/passwd" } ]
" \ ]
" 
" The "syntax" of the user-menu «list» of «dictionaries» is:
" [ 
"     \ [ "Item text …", #{ type: "type-kind", body: "the command body" } ],
"       ···
"       ···
"     \ [ "Item N text …", #{ <configuration 2> } ]
" \ ]
" 
" The meaning of the dictionary keys:
"
" — The "type" is one of: "ex", "code", "other-item", "n-mapping", "i-mapping".
" — The "{command body}" is either (a) an Ex command, like ":w" or "w", (b) an
"   inline code, like, e.g.: "let g:var = 1", (c) an item text or ID of the
"   other user menu entry, e.g.: "Ope n …" or "1".
"   
" There are also some optional, advanced keys of the dictionary:
" [ [ "…", #{ …,
"     \   opts: "options",
"     \   smessage: "start-message-text",
"     \   message: "message-text",
"     \   prompt: "prompt-text",
"     \   chain: "text-or-id",
"     \   body2: "additional command body of type <code>",
"     \ }
" \ ] ]
"   
" — The "options" is a comma- or space-separated list of subset of these
"   options: "keep-menu-open", "only-in-normal", "only-in-insert",
"   "only-in-visual", "only-in-cmd", "only-in-sh", "always-show",
"   "cancel-ex-cmd".
"   — The "keep-menu-open" option causes the menu to be reopened immediately
"     after the selected command will finish executing.
"   — The "only-in-…" options show the item only if the menu is started in the
"     given mode, for example when inserting text, unless also the "always-show"
"     option is specified, in which case the item is being always displayed,
"     however it's executed *only* in the given mode (an error is displayed if
"     the mode is wrong).
"   — The "cancel-ex-cmd" option causes the currently typed-in command (i.e.:
"     the text: ":… text …" in the command line window) to be discarded when the
"     menu is started (otherwise the text/the command is being always restored
"     after the menu closes → right before executing the selected command; this
"     allows to define a menu item that does something with the command, e.g.:
"     quotes slashes within it).
" — The "text-or-id" is either the text of the other user-menu item (the one to
"   chain-up/run after the edited item) or an ID of it.
" — The "start-message-text" is a message text to be shown *before* running the
"   command. It can start with a special string: "hl:<HL-group>:…" to show the
"   message in a specified color.
" — The "message-text" is a message text to be shown after running the command.
" — The "prompt-text" is a prompt-message text to be show when asking for the
"   user input (which is then assigned to the g:user_menu_prompt_input).
" — The "additional command body" is an inline code (not a single Ex command) to
"   be run immediately after executing the main body ↔ the main command part.
" 

" FUNCTION: VimPopMenuInitFT()
" A function that's called when the filetype of the buffer is known.
func! VimPopMenuInitFT()
endfun

" FUNCTION: VimPopMenuInitBR()
" A funcion that's called when the buffer is loaded.
func! VimPopMenuInitBR()
    let b:user_menu_cmode_cmd = ""
endfun

" FUNCTION: VimPopMenuStart() {{{
func! VimPopMenuStart()
    echohl Constant | echom "∞∞∞ VimPopMenuStart ∞∞∞ Mode:" mode()
                \ (!empty(b:user_menu_cmode_cmd) ? "××× Cmd: ".string(b:user_menu_cmode_cmd)." ×××" : "" )
    echohl None

    let menu = g:user_menu
    let items = []
    let [opr,ops] = [ '(^|[[:space:]]+|,)', '([[:space:]]+|,|$)' ]
    for entry in menu
        " Fetch the options of the item.
        let opts = get(entry[1], 'opts', '')

        " The item shown only when the menu started in insert mode?
        if opts =~ '\v'.opr.'only-in-insert'.ops && opts !~ '\v'.opr.'always-show'.ops
            if mode() !~# '\v^(R[cvx]=|i[cx]=)' | continue | endif
        endif
        " The item shown only when the menu started in normal mode?
        if opts =~ '\v'.opr.'only-in-normal'.ops && opts !~ '\v'.opr.'always-show'.ops
            if mode() !~# '\v^n(|o|ov|oV|oCTRL-V|iI|iR|iV).*' | continue | endif
        endif
        " The item shown only when the menu started in visual mode?
        if opts =~ '\v'.opr.'only-in-visual'.ops && opts !~ '\v'.opr.'always-show'.ops
            if mode() !~# '\v^([vV]|CTRL-V|[sS]|CTRL-S)$' | continue | endif
        endif
        " The item shown only when the menu started when entering commands?
        if opts =~ '\v'.opr.'only-in-ex'.ops && opts !~ '\v'.opr.'always-show'.ops
            if mode() !~# '\v^c[ve]=' | continue | endif
        endif
        " The item shown only when the menu started when a job is running?
        if opts =~ '\v'.opr.'only-in-sh'.ops && opts !~ '\v'.opr.'always-show'.ops
            if mode() !~# '\v^[\!t]$' | continue | endif
        endif

        " Support embedding variables in the text via {var}.
        let entry[0] = substitute(entry[0], '\v\{([sgb]\:[a-zA-Z_][a-zA-Z0-9_]*)\}', '\=eval(submatch(1))', '')
        call add( items, entry[0] )
    endfor

    " Special actions needed for command mode.
    if mode() =~# '\v^c[ve]='
        if empty(b:user_menu_cmode_cmd)
            let b:user_menu_cmode_cmd = getcmdline()
        else
            " Ensure that no stray command will be left.
            let b:user_menu_cmode_cmd = ""
        endif
    endif

    call popup_menu( items, #{ 
                \ callback: 'VimUserMenuMain',
                \ time: 20000,
                \ border: [ ],
                \ fixed: 0,
                \ flip: 1,
                \ title: ' VIM User Menu ',
                \ drag: 1,
                \ resize: 1,
                \ close: 'button',
                \ highlight: 'Constant',
                \ borderhighlight: [ 'Statement', 'Statement', 'Statement', 'Statement' ],
                \ padding: [ 1, 1, 1, 1 ] } )
                " \ borderchars: ['—', '|', '—', '|', '┌', '┐', '┘', '└'],
    redraw

    return b:user_menu_cmode_cmd
endfun " }}}

" FUNCTION: VimUserMenuMain() {{{
func! VimUserMenuMain(id, something)
    " Should restore the command line?
    if !empty(b:user_menu_cmode_cmd)
        call feedkeys("\<ESC>:".b:user_menu_cmode_cmd,"n")
        let b:user_menu_cmode_cmd = ''
    endif
endfunction
" }}}

"""""""""""""""""" UTILITY FUNCTIONS

func! Mapped(fn, l)
    let new_list = deepcopy(a:l)
    call map(new_list, string(a:fn) . '(v:val)')
    return new_list
endfun

func! Filtered(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, string(a:fn) . '(v:val)')
    return new_list
endfun

func! FilteredNot(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, '!'.string(a:fn) . '(v:val)')
    return new_list
endfun

func! CreateEmptyList(name)
    eval("let ".a:name." = []")
endfun

"""""""""""""""""" THE SCRIPT BODY

augroup VimPopMenuInitGroup
    au!
    au FileType * call VimPopMenuInitFT()
    au BufRead * call VimPopMenuInitBR()
augroup END

inoremap <expr> <F12> VimPopMenuStart()
nnoremap <expr> <F12> VimPopMenuStart()
vnoremap <expr> <F12> VimPopMenuStart()
cmap <F12> <C-\>eVimPopMenuStart()<CR>
" Following doesn't work as expected…'
onoremap <expr> <F12> VimPopMenuStart()

" vim:set ft=vim tw=80 et sw=4 sts=4 foldmethod=marker:
