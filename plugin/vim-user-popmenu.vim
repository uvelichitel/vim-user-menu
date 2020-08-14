let s:default_user_menu = [
            \ [ "Save", #{ type: 'ex', body: ':w', opts: "only-in-insert,always-something" } ],
            \ [ "Toggle completion {g:vichord_summaric_completion_time}", #{ type: 'code', body: 'let g:vichord_search_in_let = 1 - g:vichord_search_in_let', opts: "only-in-normal" } ],
            \ [ "Open …", #{ type: 'ex', body: 'Ex', opts: "only-in-visual"} ],
            \ [ "← Other… →", #{ type: 'ex', body: 'Ex', opts: "always-show", message: "hl:um_lblue2:Launched the file explorer."} ],
            \ [ "∧∧ YET another… ∧∧", #{ type: 'ex', body: 'Ex', opts: "always-show"} ]
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
" — The "type" is one of: "ex"/"cmd", "code", "other-item", "n-mapping",
"   "i-mapping".
"
" — The "{command body}" is either:
"   — A Ex command, like ":w" or "w". Type: "ex" (or the alias "cmd") causes
"     such command to be run.
"   — An inline code, like, e.g.: "let g:var = 1". Type: "code".
"   — An item text or an ID of the other user menu entry, e.g.: "Open …" or "1".
"     Type "other-item" will cause the given other menu item to be run, only. 
"   — An sequence of keys of a complex normal command. Type: "n-mapping" invokes
"     the keys.
"   — An sequence of keys of a complex insert-mode mapping. Type: "i-mapping"
"     invokes the keys (feeds them to the editor) potentially causing various
"     insert-mode mappings to trigger.
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
"
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
"
" — The "text-or-id" is either the text of the other user-menu item (the one to
"   chain-up/run after the edited item) or an ID of it.
"
" — The "start-message-text" is a message text to be shown *before* running the
"   command. It can start with a special string: "hl:<HL-group>:…" to show the
"   message in a specified color.
"
" — The "message-text" is a message text to be shown after running the command.
"
" — The "prompt-text" is a prompt-message text to be show when asking for the
"   user input (which is then assigned to the g:user_menu_prompt_input).
"
" — The "additional command body" is an inline code (not a single Ex command) to
"   be run immediately after executing the main body ↔ the main command part.
" 

" FUNCTION: UserMenu_InitFT() {{{
" A function that's called when a new buffor is created.
func! UserMenu_InitBufAdd() 
    let b:user_menu_cmode_cmd = ""
    let s:current_menu = {}
    let s:current_menu[bufnr()] = []
endfunc
" }}}

" FUNCTION: UserMenu_EnsureInit() {{{
func! UserMenu_EnsureInit()
    if !exists("b:user_menu_cmode_cmd")
        call UserMenu_InitBufAdd()
        return 0
    endif
    return 1
endfunc
" }}}

" FUNCTION: UserMenu_InitFileType() {{{
" A funcion that's called when the buffer is loaded.
func! UserMenu_InitFileType()
    call UserMenu_InitBufAdd()
endfunc
" }}}

" FUNCTION: UserMenu_Start() {{{
func! UserMenu_Start()
    call s:msg(4,"⟁⟁⟁ UserMenu_Start ⟁⟁⟁ Mode:", mode(),
                \ (!empty(UserMenu_GetBufOrSesVar("user_menu_cmode_cmd")) ? 
                \ "←·→ Cmd: ".string(UserMenu_GetBufOrSesVar("user_menu_cmode_cmd")) : "" ))
    echohl None

    call UserMenu_EnsureInit()

    let [opr,ops] = [ '(^|[[:space:]]+|,)', '([[:space:]]+|,|$)' ]

    " The source of the menu…
    let menu = get(g:,'user_menu', s:default_user_menu)
    " … and the temporary (it'll exist till the selection), built effect of it.
    let s:current_menu[bufnr()] = []
    " The list of items passed to popup_menu()
    let items = []
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
        call add( s:current_menu[bufnr()], entry )
    endfor

    " Special actions needed for command mode.
    if mode() =~# '\v^c[ve]=' && UserMenu_GetBufOrSesVar("user_menu_init_cmd_mode") != 1
        if empty(UserMenu_GetBufOrSesVar("user_menu_cmode_cmd"))
            call UserMenu_SetBufOrSesVar("user_menu_cmode_cmd", ':'.getcmdline())
            call UserMenu_SetBufOrSesVar("user_menu_init_cmd_mode", 1)
            call feedkeys("\<ESC>:","n")
            call feedkeys("\<F12>")
            call s:msg(5,"Setting command line to •⟼ appear ⟻• as:", UserMenu_GetBufOrSesVar("user_menu_cmode_cmd"))
            call feedkeys("\<C-U>:echo '".UserMenu_GetBufOrSesVar("user_menu_cmode_cmd")."'\<CR>","n")
            return ''
        else
            " Ensure that no stray command will be left.
            call UserMenu_SetBufOrSesVar("user_menu_cmode_cmd", "")
        endif
    endif

    call popup_menu( items, #{ 
                \ callback: 'UserMenu_MainCallback',
                \ filter: 'UserMenu_KeyFilter',
                \ filtermode: "a",
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

    return UserMenu_GetBufOrSesVar('user_menu_cmode_cmd')
endfunc " }}}

" FUNCTION: UserMenu_MainCallback() {{{
func! UserMenu_MainCallback(id, result)
    " Carefully establish the selection.
    let [it,got_it] = [ [ "", {} ], 0 ]
    if a:result > 0 && a:result <= len(s:current_menu[bufnr()])
        let [it,got_it] = [s:current_menu[bufnr()][a:result - 1], 1]
    endif

    " Important, base debug log.
    call s:msg(2,"⟁⟁ Callback ⟁⟁ °id° ≈≈", a:result, "←·→", (got_it ?
                \ string(it[0])." ←·→ TPE ·".it[1]['type']."· BDY ·".it[1]['body']."·" : "≠"))
    echohl None

    " Should restore the command line?
    if !empty(UserMenu_GetBufOrSesVar("user_menu_cmode_cmd"))
        call feedkeys("\<C-U>\<ESC>".UserMenu_GetBufOrSesVar("user_menu_cmode_cmd"),"n")
    endif
    call UserMenu_SetBufOrSesVar("user_menu_cmode_cmd", "")

    " The menu has been canceled? (ESC, ^C, cursor move)
    if !got_it
        if a:result > len(a:result)
            call s:msg(0, "Error: the index is too large →→ •••", a:result, ">",
                        \ len(s:current_menu), "•••")
        endif

        return
    endif

    " Output message before the command?
    if has_key(it[1],'smessage') 
        call s:msg(4,it[1]['smessage'])
    endif

    " Read the attached action specification and perform it.
    if it[1]['type'] =~ '\v^(ex|cmd)$'
        exe ":".it[1]['body']
    else
        call s:msg(0, "Unrecognized ·item·: type ⟸", it[1]['type'], "⟹")
    endif

    " Output message after the command?
    if has_key(it[1],'message') 
        call s:msg(4,it[1]['message'])
    endif
endfunction
" }}}

"""""""""""""""""" HELPER FUNCTIONS {{{

" FUNCTION: UserMenu_KeyFilter() {{{
func! UserMenu_KeyFilter(id,key)
    redraw
    let mode = UserMenu_GetBufOrSesVar("user_menu_init_cmd_mode")
    if mode > 0
        if a:key == "\<CR>"
            call UserMenu_SetBufOrSesVar("user_menu_init_cmd_mode", 0)
            call s:msg(3, mode(), "←←← <CR> →→→ end-passthrough ··· user_menu_init_cmd_mode",
                        \ mode,"···")
        endif
        " Don't consume the key.
        return 0
    else
        let result = popup_filter_menu(a:id, a:key)
        call s:msg(3, mode(), "←←←", a:key, "→→→ filter °°° user_menu_init_cmd_mode",
                    \ mode, "°°°", "ret", (mode() =~# '\v^c[ve]=') ? "forced-1" : result, "°°°")

        return (mode() =~# '\v^c[ve]=') ? 1 : result
    endif
endfunc " }}}
" FUNCTION: s:msg(hl,...) {{{
" 0 - error         LLEV=0 will show only them
" 1 - warning       LLEV=1
" 2 - info          …
" 3 - notice        …
" 4 - debug         …
" 5 - debug2        …
func! s:msg(hl, ...)
    " Log only warnings and errors by default.
    if a:hl > get(g:,'user_menu_log_level', 1) || a:0 == 0
        return
    endif

    " Make a copy of the input.
    let args = deepcopy(type(a:000[0]) == 3 ? a:000[0] : a:000)
    let hl = a:hl

    " Expand any variables.
    for idx in range(len(args))
        if args[idx] =~# '\v^[[:space:]]*[slgab]:[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*$'
            let args[idx] = eval(args[idx])
        endif
    endfor

    " Finally: detect any hl:…: prefix, select the color, output the message.
    let c = ["Error", "WarningMsg", "um_gold", "um_green3", "um_blue", "None"]
    let mres = matchlist(args[0],'\v^hl:([^:]*):(.*)$')
    let [hl,a1] = !empty(mres) ? [ (mres[1] =~# '^\d\+$' ? c[mres[1]] : mres[1]), mres[2] ]
                \ : [ c[hl], args[0] ]
    let hl = (hl !~# '\v^(\d+|um_[a-z0-9]+|WarningMsg|Error)$') ? 'um_'.hl : hl
    exe 'echohl ' . hl
    echom join( flatten( ( len(args) > 1 ) ? [a1,args[1:]] : [a1]) )
    echohl None 
endfunc
" }}}

" FUNCTION: s:msgcmdimpl(hl,...) {{{
func! s:msgcmdimpl(hl, bang, ...)
    let hl = !empty(a:bang) ? 0 : a:hl
    call s:msg(hl, a:000)
endfunc
" }}}
" FUNCTION: Msg(hl, ...) {{{
func! Msg(hl, ...)
    call s:msg(a:hl, join(a:000))
endfunc
" }}}

" FUNCTION: UserMenu_GetBufOrSesVar() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
func! UserMenu_GetBufOrSesVar(var_to_read)
    if exists("b:" . a:var_to_read)
        return get( b:, a:var_to_read, '' )
    elseif exists("s:" . a:var_to_read)
        return get( s:, a:var_to_read, '' )
    else
        call s:msg(1, "·• Warning «Get…» •· →→ non-existent parameter given: ⟁", string(a:var_to_read), "⟁")
    endif
endfunc
" }}}

" FUNCTION: UserMenu_SetBufOrSesVar() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
func! UserMenu_SetBufOrSesVar(var_to_set, value_to_set)
    let b:[a:var_to_set] = a:value_to_set
    if exists("b:" . a:var_to_set)
        let b:[a:var_to_set] = a:value_to_set
        return 1
    " FIXME
    elseif 0 || exists("s:" . a:var_to_set)
        let s:[a:var_to_set] = a:value_to_set
        return 2
    else
        call s:msg(1, "·• Warning «Set…» •· →→ non-existent parameter given: ⟁", string(a:var_to_set), "⟁")
        return 0
    endif
endfunc
" }}}

"""""""""""""""""" THE END OF THE HELPER FUNCTIONS }}}

"""""""""""""""""" UTILITY FUNCTIONS {{{

func! Mapped(fn, l)
    let new_list = deepcopy(a:l)
    call map(new_list, string(a:fn) . '(v:val)')
    return new_list
endfunc

func! Filtered(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, string(a:fn) . '(v:val)')
    return new_list
endfunc

func! FilteredNot(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, '!'.string(a:fn) . '(v:val)')
    return new_list
endfunc

func! CreateEmptyList(name)
    eval("let ".a:name." = []")
endfunc

"""""""""""""""""" THE END OF THE UTILITY FUNCTIONS }}}

"""""""""""""""""" THE SCRIPT BODY {{{

augroup UserMenu_InitGroup
    au!
    au BufAdd * call UserMenu_InitBufAdd()
    au BufRead * call UserMenu_InitFileType()
augroup END

inoremap <expr> <F12> UserMenu_Start()
nnoremap <expr> <F12> UserMenu_Start()
vnoremap <expr> <F12> UserMenu_Start()
cmap <F12> <C-\>eUserMenu_Start()<CR>
" Following doesn't work as expected…'
onoremap <expr> <F12> UserMenu_Start()
command! -nargs=+ -count=4 -bang -bar UMsg call s:msgcmdimpl(<count>,<q-bang>,<f-args>)
hi def um_norm ctermfg=7
hi def um_blue ctermfg=27
hi def um_blue1 ctermfg=32
hi def um_blue2 ctermfg=75
hi def um_lblue ctermfg=50
hi def um_lblue2 ctermfg=75 cterm=bold
hi def um_orange ctermfg=172
hi def um_gold ctermfg=220
hi def um_yellow ctermfg=190
hi def um_lyellow ctermfg=yellow cterm=bold
hi def um_lyellow2 ctermfg=221
hi def um_lyellow3 ctermfg=226
hi def um_green ctermfg=green
hi def um_lgreen ctermfg=lightgreen
hi def um_green2 ctermfg=35
hi def um_lgreen2 ctermfg=82
hi def um_green3 ctermfg=40
hi def um_orange ctermfg=172

"""""""""""""""""" THE END OF THE SCRIPT BODY }}}

" vim:set ft=vim tw=80 et sw=4 sts=4 foldmethod=marker:
