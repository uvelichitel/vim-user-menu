" ·•« User Menu Plugin »•· ·•« zphere-zsh/vim-user-popmenu »•·
" Copyright (c) 2020 « Sebastian Gniazdowski ».
" License: « Gnu GPL v3 ».
" 
" Example user-menu «list» of «dictionaries»:
" 
" let g:user_menu = [
"     \ [ "Reload",      #{ type: "cmd",  body: ":ed" } ],
"     \ [ "Save",        #{ type: "cmd",  body: ":w!" } ],
"     \ [ "Load passwd", #{ type: "expr", body: "MyFunction()" } ]
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
" — The "type" is one of: "cmd", "expr", "other-item", "n-mapping",
"   "i-mapping", "c-mapping".
"
" — The "{command body}" is either:
"   — A Ex command, like ":w" or "w". Type: "cmd" causes such command to be
"     run.
"   — An expression code, like, e.g.: "MyFunction()". Type: "expr".
"   — A sequence of norm commands, like, e.g.: "\<C-W>gf". Type: "norm" and
"     "norm!".
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
"     \   body2: "additional command body of type <cmd>",
"     \   predic: "expression",
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
"   message in a specified color. There are multiple easy to use hl-groups, like
"   green,lgreen,yellow,lyellow,lyellow2,blue,blue2,lblue,lblue2,etc.
"
" — The "message-text" is a message text to be shown after running the command.
"
" — The "prompt-text" is a prompt-message text to be show when asking for the
"   user input (which is then assigned to the g:user_menu_prompt_input).
"
" — The "additional command body" is an Ex command to be run immediately after
"   executing the main body ↔ the main command part.
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
        2UMsg No \b:var detected ⟵⟶ calling: ➤➤➤ ☛ \UserMenu_InitBufAdd() ☚…
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
    let s:cmd = UserMenu_BufOrSesVar("user_menu_cmode_cmd", getcmdline())
    UMsg °°° UserMenu_Start °°° Mode: mode() ((!empty(s:cmd)) ? '←·→ Cmd: '.string(s:cmd):'')
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
	let opts_key = get(entry[1], 'opts', '')
	let opts_in = (type(opts_key) == 3) ? opts_key : split(opts_key, '\v(\s+|,)')
	call add(entry, {})
	call filter( opts_in, "!empty(extend(entry[2], { v:val : 1 }))" )
	let opts = entry[2]
'
        " The item shown only when the menu started in insert mode?
        if has_key(l:opts, 'only-in-insert') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^(R[cvx]=|i[cx]=)' | continue | endif
        endif
        " The item shown only when the menu started in normal mode?
        if has_key(l:opts, 'only-in-normal') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^n(|o|ov|oV|oCTRL-V|iI|iR|iV).*' | continue | endif
        endif
        " The item shown only when the menu started in visual mode?
        if has_key(l:opts, 'only-in-visual') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^([vV]|CTRL-V|[sS]|CTRL-S)$' | continue | endif
        endif
        " The item shown only when the menu started when entering commands?
        if has_key(l:opts, 'only-in-ex') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^c[ve]=' | continue | endif
        endif
        " The item shown only when the menu started when a job is running?
        if has_key(l:opts, 'only-in-sh') && !has_key(l:opts,'always-show')
            if mode() !~# '\v^[\!t]$' | continue | endif
        endif

        " Support embedding variables in the text via {var}.
        let entry[0] = substitute(entry[0], '\v\{([sgb]\:[a-zA-Z_][a-zA-Z0-9_]*)\}', '\=eval(submatch(1))', '')
        call add( items, entry[0] )
        call add( s:current_menu[bufnr()], entry )
    endfor

    " Special actions needed for command mode.
    if mode() =~# '\v^c[ve]='
        call UserMenu_BufOrSesVarSet("user_menu_cmode_cmd", ':'.getcmdline())
        call UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode", 1)
        call UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode_once", "once")
        call feedkeys("\<Up>","n")
    endif

    call popup_menu( items, #{ 
                \ callback: 'UserMenu_MainCallback',
                \ filter: 'UserMenu_KeyFilter',
                \ filtermode: "a",
                \ time: 30000,
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
    redraw

    return !empty(UserMenu_BufOrSesVar("user_menu_cmode_cmd")) ?
		\ 'echo "'.escape(UserMenu_BufOrSesVar("user_menu_cmode_cmd"),'"')."\"" : ""
endfunc " }}}

" FUNCTION: UserMenu_MainCallback() {{{
func! UserMenu_MainCallback(id, result)
    " Carefully establish the selection.
    let [s:it,s:got_it,s:result] = [ [ "", {} ], 0, a:result ]
    if a:result > 0 && a:result <= len(s:current_menu[bufnr()])
        let [s:it,s:got_it] = [s:current_menu[bufnr()][a:result - 1], 1]
    endif

    " Important, base debug log.
    2UMsg °° Callback °° °id° ≈≈ s:result ←·→ (s:got_it ? string(s:it[0]).' ←·→ TPE ·'.s:it[1]['type'].'· BDY ·'.s:it[1]['body'].'·' : '≠')
    echohl None

    " Should restore the command line?
    let had_cmd = 0
    if !empty(UserMenu_BufOrSesVar("user_menu_cmode_cmd"))
	" TODO2: timer, aby przetworzyć te klawisze przed wywołaniem komendy
        call UserMenu_RestoreCmdLineFrom(UserMenu_BufOrSesVar("user_menu_cmode_cmd"))
	let had_cmd = 1
    endif
    call UserMenu_BufOrSesVarSet("user_menu_cmode_cmd", "")
    call UserMenu_CleanupSesVars()

    " The menu has been canceled? (ESC, ^C, cursor move)
    if !s:got_it
        if a:result > len(a:result)
            call s:msg(0, "Error: the index is too large →→ •••", a:result, ">",
                        \ len(s:current_menu), "•••")
        endif

        return
    endif

    " Output message before the command?
    if has_key(s:it[1],'smessage') 
        call s:msg(4,UserMenu_ExpandVars(s:it[1]['smessage'])) 
    endif

    " Read the attached action specification and perform it.
    if s:it[1]['type'] == 'cmd'
        exe s:it[1]['body']
    elseif s:it[1]['type'] == 'expr'
        call eval(s:it[1]['body'])
    elseif s:it[1]['type'] =~# '\v^norm(\!|)$'
        exe s:it[1]['type'] s:it[1]['body']
    else
        call s:msg(0, "Unrecognized ·item·: type ⟸", it[1]['type'], "⟹")
    endif

    " Output message after the command?
    if has_key(it[1],'message') 
        call s:msg(4,UserMenu_ExpandVars(it[1]['message']))
    endif

    let l:opts = it[2]

    " Reopen the menu?
    if has_key(l:opts, 'keep-menu-open')
        call timer_start(750, function("s:deferedMenuStart"))
    endif

    " Cancel ex command?
    if has_key(l:opts, 'cancel-ex-cmd') && had_cmd
	call feedkeys("\<C-U>\<BS>","n")
    endif

endfunction
" }}}

"""""""""""""""""" HELPER FUNCTIONS {{{

" FUNCTION: UserMenu_KeyFilter() {{{
func! UserMenu_KeyFilter(id,key)
    redraw
    let s:tryb = UserMenu_BufOrSesVar("user_menu_init_cmd_mode")
    let s:key = a:key
    if mode() =~# '\v^c[ve]=' | call timer_start(250, function("s:redraw")) | endif
    if s:tryb > 0
        if a:key == "\<CR>"
            call UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode", 0)
            3UMsg mode() ←←← <CR> →→→ end-passthrough ··· user_menu_init_cmd_mode s:tryb ···
        elseif UserMenu_BufOrSesVar("user_menu_init_cmd_mode_once") == "once"
            call UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode_once", "already-ran")
            3UMsg mode() ←←← s:key →→→ echo/fake-cmd-line ··· user_menu_init_cmd_mode s:tryb ···
            UMsg Setting command line to •→ appear ←• as: UserMenu_BufOrSesVar('user_menu_cmode_cmd')
            call feedkeys("\<CR>","n")
        else
            3UMsg mode() ←←← s:key →→→ passthrough…… ··· user_menu_init_cmd_mode s:tryb ···
        endif
        " Don't consume the key — pass it through, unless it's <Up>.
        redraw
        return (a:key == "\<Up>") ? popup_filter_menu(a:id, a:key) : 0
    else
        let s:result = popup_filter_menu(a:id, a:key)
        3UMsg mode() ←←← s:key →→→ filtering-path °°° user_menu_init_cmd_mode
                    \ s:tryb °°° ret ((mode()=~#'\v^c[ve]=') ? 'forced-1' : s:result) °°°
        redraw
        return (mode() =~# '\v^c[ve]=') ? 1 : s:result
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

    " Expand any variables and concatenate separated atoms wrapped in parens.
    let start_idx = -1
    let new_args = []
    for idx in range(len(args))
        let arg = args[idx]
        " Unclosed paren?
        " Discriminate two special cases: (mode() and (mode(sub())
        if arg =~# '\v^\(.*([^)]|\([^)]*\)|\([^(]*\([^)]*\)[^)]*\))$'
            let start_idx = idx
        " A free, closing paren?
        elseif start_idx >= 0 && arg =~# '\v^[^(].*\)$' && arg !~ '\v\([^)]*\)$'
            call add(new_args,eval(join(args[start_idx:idx])))
            let start_idx = -1
            continue
        endif
    
        if start_idx == -1
            " A variable?
            if arg =~# '\v^\s*[sgb]:[a-zA-Z_][a-zA-Z0-9_]*\s*$'
                let arg = eval(arg)
            " A function call or an expression wrapped in parens?
            elseif arg =~# '\v^\s*([a-zA-Z_][a-zA-Z0-9_-]*)=\s*\(.*\)\s*$'
                let arg = eval(arg)
            " A \-quoted atom?
            elseif arg[0] == '\'
                let arg = arg[1:]
            endif

            " Store/save the element.
            call add(new_args, arg)
        endif
    endfor
    let args = new_args

    " Finally: detect any hl:…: prefix, select the color, output the message.
    let c = ["Error", "WarningMsg", "um_gold", "um_green3", "um_blue", "None"]
    let mres = matchlist(args[0],'\v^hl:([^:]*):(.*)$')
    let [hl,a1] = !empty(mres) ? [ (mres[1] =~# '^\d\+$' ? c[mres[1]] : mres[1]), mres[2] ]
                \ : [ c[hl], args[0] ]
    let hl = (hl !~# '\v^(\d+|um_[a-z0-9]+|WarningMsg|Error)$') ? 'um_'.hl : hl
    exe 'echohl ' . hl
    echom join( Flatten( ( len(args) > 1 ) ? [a1,args[1:]] : [a1]) )
    echohl None 
endfunc
" }}}

" FUNCTION: s:msgcmdimpl(hl,...) {{{
func! s:msgcmdimpl(hl, bang, ...)
    let hl = !empty(a:bang) ? 0 : a:hl
    call s:msg(hl, a:000)
endfunc
" }}}

" FUNCTION: s:redraw(timer) {{{
func! s:redraw(timer)
    :5UMsg △ redraw called △
    redraw
endfunc
" }}}

" FUNCTION: s:deferedMenuStart(timer) {{{
func! s:deferedMenuStart(timer)
    call UserMenu_Start()
    echohl um_lyellow
    echom "Opened again the menu."
    echohl None
    redraw
endfunc
" }}}

" FUNCTION: UserMenu_BufOrSesVar() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
func! UserMenu_BufOrSesVar(var_to_read,...)
    let s:tmp = a:var_to_read
    if exists("s:" . a:var_to_read)
        return get( s:, a:var_to_read, a:0 ? a:1 : '' )
    elseif exists("b:" . a:var_to_read)
        return get( b:, a:var_to_read, a:0 ? a:1 : '' )
    else
        1UMsg ·• Warning «Get…» •· →→ non-existent parameter given: ⟁ s:tmp ⟁
        return a:0 ? a:1 : ''
    endif
endfunc
" }}}

" FUNCTION: UserMenu_CleanupSesVars() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
func! UserMenu_CleanupSesVars()
    if has_key(s:,'user_menu_init_cmd_mode')
        call remove(s:,'user_menu_init_cmd_mode')
    endif
    if has_key(s:,'user_menu_init_cmd_mode_once')
        call remove(s:,'user_menu_init_cmd_mode_once')
    endif
    if has_key(s:,'user_menu_cmode_cmd')
        call remove(s:,'user_menu_cmode_cmd')
    endif
endfunc
" }}}
 
" FUNCTION: UserMenu_BufOrSesVarSet() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
func! UserMenu_BufOrSesVarSet(var_to_set, value_to_set)
    let s:tmp = a:var_to_set
    if exists("s:" . a:var_to_set)
        let s:[a:var_to_set] = a:value_to_set
    else
        if exists("b:" . a:var_to_set)
            let b:[a:var_to_set] = a:value_to_set
            return 1
        else
            1UMsg ·• Warning «Set…» •· →→ non-existent parameter given: ⟁ s:tmp ⟁
            let b:[a:var_to_set] = a:value_to_set
            if exists("b:" . a:var_to_set)
                let b:[a:var_to_set] = a:value_to_set
                return 1
            else
                let s:[a:var_to_set] = a:value_to_set
                return 0
            endif
        endif
    endif
endfunc
" }}}

" FUNCTION: UserMenu_ExpandVars {{{
func! UserMenu_ExpandVars(text)
    return substitute(a:text, '\v\{([sgb]\:[a-zA-Z_][a-zA-Z0-9_]*)\}', '\=eval(submatch(1))', '')
endfunc
" }}}

" FUNCTION: UserMenu_RestoreCmdLineFrom
func! UserMenu_RestoreCmdLineFrom(cmd)
    call feedkeys(a:cmd,"n")
endfunc
" }}}

"""""""""""""""""" THE END OF THE HELPER FUNCTIONS }}}

"""""""""""""""""" UTILITY FUNCTIONS {{{

func! Flatten(list)
    let new_list = []
    for el in a:list
        if type(el) == 3
            call extend(new_list, el)
        else
            call add(new_list, el)
        endif
    endfor
    return new_list
endfunc

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
cnoremap <F12> <C-\>eUserMenu_Start()<CR>
" Following doesn't work as expected…'
onoremap <expr> <F12> UserMenu_Start()
command! -nargs=+ -count=4 -bang -bar UMsg call s:msgcmdimpl(<count>,<q-bang>,expand("<sflnum>"),<f-args>)
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

let s:default_user_menu = [
            \ [ "Save", #{ type: 'cmd', body: ':w', opts: "only-in-insert,always-something" } ],
            \ [ "Toggle completion {g:vichord_summaric_completion_time}", #{ type: 'expr', body: 'extend(g:, #{ vichord_search_in_let : !g:vichord_search_in_let })', opts: "only-in-normal keep-menu-open", message: "hl:lblue2:Current state: {g:vichord_search_in_let}." } ],
            \ [ "Open [vis]…", #{ type: 'cmd', body: 'Ex', opts: "only-in-visual"} ],
            \ [ "← Other… [msg] →", #{ type: 'cmd', body: 'Ex', opts: "always-show", message: "hl:um_lblue2:Launched the file explorer."} ],
            \ [ "°° always canc keep °°", #{ type: 'cmd', body: 'Ex', opts: "always-show cancel-ex-cmd keep-menu-open"} ],
            \ [ "•• NEW [norm] ••", #{ type: 'norm', body: "\<C-W>n", opts: "always-show cancel-ex-cmd"} ],
            \ [ "•• Upcase Letters ••", #{ type: 'norm', body: "U", opts: "only-in-visual"} ],
            \ [ "•• Escape Command Line ••", #{ type: 'expr', body: "feedkeys('\<C-bslash>eescape(getcmdline(), \" \\\\\")\<CR>','n')", opts: ['only-in-ex'] } ],
            \ [ "•• Experiment / Command Line ••", #{ type: 'expr', body: 'feedkeys(":Ex\<CR>","n")', opts: [] } ]
            \ ]

"""""""""""""""""" THE END OF THE SCRIPT BODY }}}

" vim:set ft=vim tw=80 et sw=4 sts=4 foldmethod=marker:
