" ·•« User Menu Plugin »•· ·•« zphere-zsh/vim-user-popmenu »•·
" Copyright (c) 2020 « Sebastian Gniazdowski ».
" License: « Gnu GPL v3 ».
"
" Example user-menu «list» of «dictionaries» (note: the #{ … } syntax is a
" Dictionary that allows no quoting on keys — it's unavailable in Neovim):
"
 let g:user_menu_default = [
     \ [ "Reload",      #{ type: "cmds", body: ":edit!" } ],
     \ [ "Quit Vim",    #{ type: "cmds", body: ":qa!" } ],
     \ [ "New Window",  #{ type: "keys", body: "\<C-w>n" } ],
     \ [ "Load passwd", #{ type: "expr", body: "LoadPasswd()" } ]
 \ ]
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
" – The "type" is one of: "cmds", "expr", "norm", "keys", "other-item".
"
" – The "{command body}" is either:
"   – A Ex command, like ":w" or "w". Type: "cmds" causes such command to be
"     run.
"   – An expression code, like, e.g.: "MyFunction()". Type: "expr".
"   – A sequence of norm commands, like, e.g.: "\<C-W>gf". Type: "norm" and
"     "norm!".
"   – A sequence of keys to feed into the editor simulating input, like, e.g.:
"     "\<C-w>n". Type: "keys".
"   – An item text or an ID of the other user menu entry, e.g.: "Open …" or "1".
"     Type "other-item" will cause the given other menu item to be run, only.
"
" There are also some optional, advanced keys of the dictionary:
" [ [ "…", #{ …,
"     \   opts: "options",
"     \   smessage: "start-message-text",
"     \   message: "message-text",
"     \   prompt: "prompt-text",
"     \   chain: "text-or-id",
"     \   body2: "additional command body of type <cmds>",
"     \   predic: "expression",
"     \ }
" \ ] ]
"
" – The "options" is a comma- or space-separated list of subset of these
"   options: "keep-menu-open", "in-normal", "in-insert",
"   "in-visual", "in-cmds", "in-sh", "always-show",
"   "exit-to-norm".
"
"   – The "keep-menu-open" option causes the menu to be reopened immediately
"     after the selected command will finish executing.
"   – The "in-…" options show the item only if the menu is started in the
"     given mode, for example when inserting text, unless also the "always-show"
"     option is specified, in which case the item is being always displayed,
"     however it's executed *only* in the given mode (an error is displayed if
"     the mode is wrong).
"   – The "exit-to-norm" option causes the currently typed-in command (i.e.:
"     the text: ":… text …" in the command line window) to be discarded when the
"     menu is started (otherwise the text/the command is being always restored
"     after the menu closes → right before executing the selected command; this
"     allows to define a menu item that does something with the command, e.g.:
"     quotes slashes within it).
"
" – The "text-or-id" is either the text of the other user-menu item (the one to
"   chain-up/run after the edited item) or an ID of it.
"
" – The "start-message-text" is a message text to be shown *before* running the
"   command. It can start with a special string: "%<HL-group>. " to show the
"   message in a specified color. There are multiple easy to use hl-groups, like
"   green,lgreen,yellow,lyellow,lyellow2,blue,blue2,lblue,lblue2,etc.
"
" – The "message-text" is a message text to be shown after running the command.
"
" – The "prompt-text" is a prompt-message text to be show when asking for the
"   user input (which is then assigned to the g:user_menu_prompt_input).
"
" – The "additional command body" is an Ex command to be run immediately after
"   executing the main body ↔ the main command part.
"

function! UserMenu_Start(way)
    call s:UserMenu_Start(a:way)
endfunc
" FUNCTION: s:UserMenu_Start() {{{
function! s:UserMenu_Start(way)
    let s:way = a:way
    let s:cmds = ((s:way == "c2") ? (empty(getcmdline()) ? s:cmds : getcmdline()) : getcmdline())
    PrintSmart °°° UserMenu_Start °°° Mode: s:way ((!empty(s:cmds)) ? '←·→ Cmd: '.string(s:cmds):'')

    call s:UserMenu_EnsureInit()

    let l:state_to_desc = { 'n':'Normal.', 'c':'Command Line.',
                \ 'i':'Insert.', 'v':'Visual.', 'o':'o.' }
    let l:state_to_desc['c2'] = l:state_to_desc['c']
    if s:way !~ '\v^c2=$'
        PrintSmart 9 %lblue3.User Menu started in %2l:state_to_desc[s:way]%lblue3. mode.
    elseif s:way =~ '\v^c2=$'
        " Special actions needed for command-line state.
        if s:way == 'c'
            call s:UserMenu_BufOrSesVarSet("user_menu_cmode_cmd", ':'.s:cmds)
            call s:UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode", 'should-initialize')
            call feedkeys("\<ESC>","n")
            call add(s:timers, timer_start(70, function("s:deferredMenuReStart")))
            return ""
        endif

        let s:cmdline_like_msg = s:cmds
        if s:way == 'c2'
	    if !s:state_restarting
		7PrintSmart! p:1.5:%lblue3.User Menu started in %2Command-Line%lblue3. mode. The current-command line is:
	    endif
            let s:cmdline_like_msg = "%None.:" . s:cmdline_like_msg . "█"
            7PrintSmart! s:cmdline_like_msg
        endif
    endif
    let s:state_restarting = 0

    let [opr,ops] = [ '(^|[[:space:]]+|,)', '([[:space:]]+|,|$)' ]

    " The source of the menu…
    let menu = deepcopy(get(g:,'user_menu', g:user_menu_default))

    " … and the temporary (it'll exist till the selection), built effect of it.
    if ! exists("s:current_menu")
        let s:current_menu = {}
    endif
    let s:current_menu[bufnr()] = []
    " The list of items passed to popup_menu()
    let items = []
    for entry in menu
        " Fetch the options of the item.
	let opts_key = get(entry[1], 'opts', '')
	let opts_in = (type(opts_key) == 3) ? opts_key : split(opts_key, '\v(\s+|,)')
	call add(entry, {})
	call filter( opts_in, "!empty(extend(entry[2], { v:val : 1 }))" )
	let s:opts = entry[2]
'
        " Verify show-if
        if has_key(entry[1], 'show-if')
            if !eval(entry[1]['show-if']) | continue | endif
        endif

        let [reject,accept] = [ 0, 0 ]
        " The item shown only when the menu started in insert mode?
        if has_key(s:opts, 'in-insert') && !has_key(s:opts,'always-show')
            if s:way !~# '\v^(R[cvx]=|i[cx]=)' | let reject += 1 | else | let accept += 1 | endif
        endif
        " The item shown only when the menu started in normal mode?
        if has_key(s:opts, 'in-normal') && !has_key(s:opts,'always-show')
            if s:way !~# '\v^n(|o|ov|oV|oCTRL-V|iI|iR|iV).*' | let reject += 1 | else | let accept += 1 | endif
        endif
        " The item shown only when the menu started in visual mode?
        if has_key(s:opts, 'in-visual') && !has_key(s:opts,'always-show')
            if s:way !~# '\v^([vV]|CTRL-V|[sS]|CTRL-S)$' | let reject += 1 | else | let accept += 1 | endif
        endif
        " The item shown only when the menu started when entering commands?
        if has_key(s:opts, 'in-ex') && !has_key(s:opts,'always-show')
            if s:way !~# '\v^c[ve]=' | let reject += 1 | else | let accept += 1 | endif
        endif
        " The item shown only when the menu started when a job is running?
        if has_key(s:opts, 'in-sh') && !has_key(s:opts,'always-show')
            if s:way !~# '\v^[!t]$' | let reject += 1 | else | let accept += 1 | endif
        endif

        if reject && ! accept
            continue
        endif
        " Support embedding variables in the text via {var}.
        let entry[0] = s:UserMenu_ExpandVars(entry[0])
        call add( items, entry[0] )
        call add( s:current_menu[bufnr()], entry )
    endfor

    hi! UMPmenu ctermfg=220 ctermbg=darkblue
    hi! UMPmenuSB ctermfg=220 ctermbg=darkblue
    hi! UMPmenuTH ctermfg=220 ctermbg=darkblue
    hi! PopupSelected ctermfg=17 ctermbg=lightblue
    hi! PmenuSel ctermfg=17 ctermbg=lightblue

    let secarg = {
        \ 'callback': 'UserMenu_MainCallback',
        \ 'filter': 'UserMenu_KeyFilter',
        \ 'filtermode': "a",
        \ 'time': 30000,
        \ 'mapping': 0,
        \ 'border': [ ],
        \ 'fixed': 1,
        \ 'wrap': 0,
        \ 'maxheight': &lines-8,
        \ 'maxwidth': &columns-20,
        \ 'flip': 1,
        \ 'title': ' VIM User Menu ≈ ' . l:state_to_desc[s:way] . ' ≈ ',
        \ 'drag': 1,
        \ 'resize': 1,
        \ 'close': 'button',
        \ 'highlight': 'UMPmenu',
        \ 'scrollbar': 1,
        \ 'scrollbarhighlight': 'UMPmenuSB',
        \ 'thumbhighlight': 'UMPmenuTH',
        \ 'cursorline': 1,
        \ 'borderhighlight': [ 'um_gold', 'um_gold', 'um_gold', 'um_gold' ],
        \ 'padding': [ 0, 0, 0, 0 ] }

    if exists('*popup_menu')
        " Vim
        call popup_menu(items, secarg)
        " The plugin currently is unable to render the popup, so… no NeoVim.
    elseif has('nvim') && exists('g:loaded_popup_menu_plugin')
        " Neovim
        " g:loaded_popup_menu_plugin is defined by kamykn/popup-menu.nvim.
        call popup_menu#open(items, secarg)
    else
        " Old vim/neovim
        let index = inputitems(items)
        call UserMenu_MainCallback(index)
    endif

    redraw

    return ""
endfunc " }}}
" FUNCTION: s:UserMenu_StartSubMenu() {{{
function! s:UserMenu_StartSubMenu()
endfunc
" }}}
" FUNCTION: UserMenu_MainCallback() {{{
function! UserMenu_MainCallback(id, result)
    call s:UserMenu_MainCallback(a:id, a:result)
endfunc
" }}}
" FUNCTION: s:UserMenu_MainCallback() {{{
function! s:UserMenu_MainCallback(id, result)
    " Clear the message window.
    echon "\r\r"
    echon ''
    " Carefully establish the selection and its data.
    let [s:item,s:got_it,s:result,s:type,s:body] = [ [ "", {} ], 0, a:result, "", "" ]
    if a:result > 0 && a:result <= len(s:current_menu[bufnr()])
        let [s:item,s:got_it] = [s:current_menu[bufnr()][a:result - 1], 1]
        let [s:type,s:body] = [s:item[1]['type'],s:item[1]['body']]
    endif

    " Important, base debug log.
    2PrintSmart °° Callback °° °id° ≈≈ s:result ←·→ (s:got_it ? string(s:item[0]).' ←·→ TPE ·'.s:type.'· BDY ·'.s:body.'·' : '≠')

    if s:got_it
        let s:opts = s:item[2]

        " Reopen the menu?
        if has_key(s:opts, 'keep-menu-open')
            call add(s:timers, timer_start(170, function("s:deferredMenuReStart")))
            let s:state_restarting = 1
        endif
    endif

    " Should restore the command line?
    let s:had_cmd = 0
    if !empty(s:UserMenu_BufOrSesVar("user_menu_cmode_cmd")) && !s:state_restarting
	" TODO2: timer, aby przetworzyć te klawisze przed wywołaniem komendy
        call add(s:timers,timer_start(5, function("s:UserMenu_RestoreCmdLine")))
	let s:had_cmd = 1
    endif
    call s:UserMenu_CleanupSesVars(s:way !~ '\v^c.*' ? 1 : 0)

    " The menu has been canceled? (ESC, ^C, cursor move)
    if !s:got_it
        if a:result > len(a:result)
            0PrintSmart Error: the index is too large →→ ••• s:result > len(s:current_menu) •••
        endif
        return
    endif

    " Output message before the command?
    call s:UserMenu_DeployDeferred_TimerTriggered_Message(s:item[1], 'smessage', -1)

    " Continue in the callback to fully leave the popup.
    call add( s:timers, timer_start(10, function("s:UserMenu_ExecuteCommand")) )
endfunction
" }}}
" FUNCTION: s:UserMenu_ExecuteCommand() {{{
function! s:UserMenu_ExecuteCommand(timer)
    call filter( s:timers, 'v:val != a:timer' )

    " Read the attached action specification and perform it.
    if s:type == 'cmds'
        exe s:body
    elseif s:type == 'expr'
        call eval(s:body)
    elseif s:type =~# '\v^norm(\!|)$'
        exe s:type s:body
    elseif s:type == 'keys'
        call feedkeys(s:body,"n")
    else
        0PrintSmart Unrecognized ·item· type: • s:type •
    endif

    " Output message after the command?
    call s:UserMenu_DeployDeferred_TimerTriggered_Message(s:item[1], 'message', 1)

    " Cancel ex command?
    if exists("s:opts") && has_key(s:opts, 'exit-to-norm') && s:had_cmd
        call feedkeys("\<C-U>\<BS>","n")
    endif
endfunc
" }}}
" FUNCTION: s:UserMenu_InitBufAdd() {{{
" A function that's called when a new buffor is created.
function! s:UserMenu_InitBufAdd()
    let b:user_menu_cmode_cmd = ""
    let s:current_menu = {}
    let s:current_menu[bufnr()] = []
endfunc
" }}}
" FUNCTION: s:UserMenu_InitBufRead() {{{
" A funcion that's called when the buffer is loaded.
function! s:UserMenu_InitBufRead()
    call s:UserMenu_InitBufAdd()
endfunc
" }}}
" FUNCTION: s:UserMenu_EnsureInit() {{{
function! s:UserMenu_EnsureInit()
    if !exists("b:user_menu_cmode_cmd")
        2PrintSmart No \b:var detected °° calling: °° « \s:UserMenu_InitBufAdd() » …
        call s:UserMenu_InitBufAdd()
        return 0
    endif
    return 1
endfunc
" }}}

"""""""""""""""""" HELPER FUNCTIONS {{{

" FUNCTION: UserMenu_KeyFilter() {{{
function! UserMenu_KeyFilter(id,key)
    return s:UserMenu_KeyFilter(a:id,a:key)
endfunc
" }}}
" FUNCTION: s:UserMenu_KeyFilter() {{{
function! s:UserMenu_KeyFilter(id,key)
    let s:tryb = s:UserMenu_BufOrSesVar("user_menu_init_cmd_mode")
    let s:key = a:key
    if s:way == 'c' | call add(s:timers, timer_start(250, function("s:redraw"))) | endif
    if s:tryb == 'should-initialize'
        3PrintSmart s:way ←←← s:key →→→ «INIT-path» °°° user_menu_init_cmd_mode ←·→
                    \ s:tryb °°° \s:way ←·→ s:way °°° \a:key ←·→ s:key
        call s:UserMenu_BufOrSesVarSet("user_menu_init_cmd_mode", '')
        " Consume (still somewhat conditionally ↔ depending on the filter)
        " only the (very first) Up-cursor key. It is sent automatically right
        " after starting the menu from the «active-command line» state.
        return (a:key == "\<Up>") ? popup_filter_menu(a:id, a:key) : 0
    else
        if execute(['let i=index(["k","\<Up>","\<C-E>","\<C-P>"], s:key)', 'echon i']) >= 0
            let s:key = "k"
        elseif execute(['let i=index(["j","\<Down>","\<C-Y>","\<C-N>"], s:key)', 'echon i']) >= 0
            let s:key = "j"
        elseif execute(['let i=index(["\<C-U>","g"],s:key)','echon i']) >= 0
            call feedkeys("kkkkkkk" . (i ? "kkkkkkkkkkkkkkkkkkkkkkkkkkkk" : ""),"n")
            let s:main_skip_count = 1 + 7 + (i ? 28 : 0)
        elseif execute(['let i=index(["\<C-D>","G"],s:key)','echon i']) >= 0
            call feedkeys("jjjjjjj" . (i ? "jjjjjjjjjjjjjjjjjjjjjjjjjjjj" : ""),"n")
            let s:main_skip_count = 1 + 7 + (i ? 28 : 0)
        endif

        let s:main_skip_count -= s:main_skip_count > 0 ? 1 : 0
        let s:result = popup_filter_menu(a:id, s:key)
        3PrintSmart s:way ←←← s:key →→→ filtering-path °°° user_menu_init_cmd_mode
                    \ s:tryb °°° ret ((s:way=='c') ? '~forced-1'.s:result : s:result) °°°
        return s:result
    endif
endfunc " }}}
" FUNCTION: s:UserMenu_DeployDeferred_TimerTriggered_Message() {{{
function! s:UserMenu_DeployDeferred_TimerTriggered_Message(dict,key,...)
    if a:0 && a:1 > 0
        let [s:msgs, s:msg_idx] = [ exists("s:msgs") ? s:msgs : [], exists("s:msg_idx") ? s:msg_idx : 0 ]
    endif
    if has_key(a:dict,a:key)
        let s:msg = a:dict[a:key]
        if a:0 && a:1 >= 0
            call add(s:msgs, s:msg)
            call add(s:timers, timer_start(a:0 >= 2 ? a:2 : 20, function("s:deferredMessageShow")))
            let s:msg_idx = s:msg_idx == -1 ? 0 : s:msg_idx
        else
            if type(s:msg) == 3 || !empty(substitute(s:msg,"^%[^.]*:","","g"))
                if type(s:msg) == 3
                    call s:msg(10, s:msg)
                else
                    10PrintSmart s:msg
                endif
                redraw
            endif
        endif
    endif
endfunc
" }}}
" FUNCTION: s:msg(hl,...) {{{
" 0 - error         LLEV=0 will show only them
" 1 - warning       LLEV=1
" 2 - info          …
" 3 - notice        …
" 4 - debug         …
" 5 - debug2        …
function! s:msg(hl, ...)
    " Log only warnings and errors by default.
    if a:hl < 7 && a:hl > get(g:,'user_menu_log_level', 1) || a:0 == 0
        return
    endif

    " Make a copy of the input.
    let args = deepcopy(type(a:000[0]) == 3 ? a:000[0] : a:000)
    " Strip the line-number argumen for the user- (count>=7) messages.
    if a:hl >= 7 && type(args[0]) == v:t_string &&
                \ args[0] =~ '\v^\[\d*\]$' | let args = args[1:] | endif
    " Normalize higlight/count.
    let hl = a:hl >= 7 ? (a:hl-7) : a:hl

    " Expand any variables and concatenate separated atoms wrapped in parens.
    if ! s:Messages_state
        let start_idx = -1
        let new_args = []
        for idx in range(len(args))
            let arg = args[idx]
            " Unclosed paren?
            " Discriminate two special cases: (func() and (func(sub_func())
            if start_idx == -1
                if type(arg) == v:t_string && arg =~# '\v^\(.*([^)]|\([^)]*\)|\([^(]*\([^)]*\)[^)]*\))$'
                    let start_idx = idx
                endif
            " A free, closing paren?
            elseif start_idx >= 0
                if type(arg) == v:t_string && arg =~# '\v^[^(].*\)$' && arg !~ '\v\([^)]*\)$'
                    call add(new_args,eval(join(args[start_idx:idx])))
                    let start_idx = -1
                    continue
                endif
            endif

            if start_idx == -1
                " Compensate for explicit variable-expansion requests or {:ex commands…}, etc.
                let arg = s:UserMenu_ExpandVars(arg)

                if type(arg) == v:t_string
                    " A variable?
                    if arg =~# '\v^\s*[svgb]:[a-zA-Z_][a-zA-Z0-9._]*%(\[[^]]+\])*\s*$'
                        let arg = s:UserMenu_ExpandVars("{".arg."}")
                    " A function call or an expression wrapped in parens?
                    elseif arg =~# '\v^\s*(([svgb]:)=[a-zA-Z_][a-zA-Z0-9_-]*)=\s*\(.*\)\s*$'
                        let arg = eval(arg)
                    " A \-quoted atom?
                    elseif arg[0] == '\'
                        let arg = arg[1:]
                    endif
                endif

                " Store/save the element.
                call add(new_args, arg)
            endif
        endfor
        let args = new_args
        " Store the message in a custom history.
        call add(g:messages, extend([a:hl], args))
    endif

    " Finally: detect %…. infixes, select color, output the message bit by bit.
    let c = ["Error", "WarningMsg", "gold", "green4", "blue", "None"]
    let [pause,new_msg_pre,new_msg_post] = s:UserMenu_GetPrefixValue('p%[ause]', join(args) )
    let msg = new_msg_pre . new_msg_post

    " Pre-process the message…
    let val = ""
    let [arr_hl,arr_msg] = [ [], [] ]
    while val != v:none
        let [val,new_msg_pre,new_msg_post] = s:UserMenu_GetPrefixValue('\%', msg)
        let msg = new_msg_post
        if val != v:none
            call add(arr_msg, new_msg_pre)
            call add(arr_hl, val)
        elseif !empty(new_msg_pre)
            if empty(arr_hl)
                call add(arr_msg, "")
                call add(arr_hl, hl)
            endif
            " The final part of the message.
            call add(arr_msg, new_msg_pre)
        endif
    endwhile

    " Clear the message window…
    echon "\r\r"
    echon ''

    " Post-process ↔ display…
    let idx = 0
    while idx < len(arr_hl)
        " Establish the color.
        let hl = !empty(arr_hl[idx]) ? (arr_hl[idx] =~# '^\d\+$' ?
                    \ c[arr_hl[idx]] : arr_hl[idx]) : c[hl]
        let hl = (hl !~# '\v^(-|\d+|um_[a-z0-9_]+|WarningMsg|Error)$') ? 'um_'.hl : hl
        let hl = hl == '-' ? 'None' : hl

        " The message part…
        if !empty(arr_msg[idx])
            echon arr_msg[idx]
        endif

        " The color…
        exe 'echohl ' . hl

        " Advance…
        let idx += 1
    endwhile

    " Final message part…
    if !empty(arr_msg[idx:idx])
        echon arr_msg[idx]
    endif
    echohl None

    " 'Submit' the message so that it cannot be deleted with \r…
    if s:Messages_state
        echon "\n"
    endif

    if !s:Messages_state && !empty(filter(arr_msg,'!empty(v:val)'))
        call s:UserMenu_DoPause(pause)
    endif
endfunc
" }}}
" FUNCTION: s:msgcmdimpl(hl,...) {{{
function! s:msgcmdimpl(hl, bang, linenum, ...)
    if(!empty(a:bang))
        call s:UserMenu_DeployDeferred_TimerTriggered_Message(
                    \ { 'm': (a:hl < 7 ? extend(["[".a:linenum."]"], a:000[0]) : a:000[0]) }, 'm', 1)
    else
        if exists("a:000[0][1]") && type(a:000[0][1]) == 1 && a:000[0][1] =~ '\v^\[\d+\]$'
            call s:msg(a:hl, a:000[0])
        else
            call s:msg(a:hl, extend(["[".a:linenum."]"], a:000[0]))
        endif
    endif
endfunc
" }}}
" FUNCTION: s:redraw(timer) {{{
function! s:redraw(timer)
    call filter( s:timers, 'v:val != a:timer' )
    6PrintSmart △ redraw called △
    redraw
endfunc
" }}}
" FUNCTION: s:deferredMenuReStart(timer) {{{
function! s:deferredMenuReStart(timer)
    call filter( s:timers, 'v:val != a:timer' )
    if s:way =~ '^c.*'
        call feedkeys("\<Up>","n")
    endif
    call s:UserMenu_Start(s:way == 'c' ? 'c2' : s:way)
    if s:way !~ '\v^c.*'
        let l:state_to_desc = { 'n':'Normal', 'i':'Insert', 'v':'Visual', 'o':'o' }
        7PrintSmart %lyellow3.Opened again the menu in l:state_to_desc[s:way] mode.
    endif
    redraw
endfunc
" }}}
" FUNCTION: s:deferredMessageShow(timer) {{{
function! s:deferredMessageShow(timer)
    call filter( s:timers, 'v:val != a:timer' )
    if type(s:msgs[s:msg_idx]) == 3
        call s:msg(10,s:msgs[s:msg_idx])
    else
        10PrintSmart s:msgs[s:msg_idx]
    endif
    let s:msg_idx += 1
    redraw
endfunc
" }}}
" FUNCTION: s:closePreviewPopup(timer) {{{
function! s:closePreviewPopup(timer)
    call filter( s:timers, 'v:val != a:timer' )
    let pid = popup_findpreview()
    if pid
        call popup_close(pid)
    endif
endfunc
" }}}
" FUNCTION: s:UserMenu_DoPause(pause_value) {{{
function! s:UserMenu_DoPause(pause_value)
    if a:pause_value =~ '\v^-=\d+(\.\d+)=$'
        let s:pause_value = float2nr(round(str2float(a:pause_value) * 1000.0))
    else
        return
    endif
    if s:pause_value =~ '\v^-=\d+$' && s:pause_value > 0
        call s:UserMenu_PauseAllTimers(1, s:pause_value + 10)
        exe "sleep" s:pause_value."m"
    endif
endfunc
" }}}
" FUNCTION: s:UserMenu_BufOrSesVar() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
function! s:UserMenu_BufOrSesVar(var_to_read,...)
    let s:tmp = a:var_to_read
    if exists("s:" . a:var_to_read)
        return get( s:, a:var_to_read, a:0 ? a:1 : '' )
    elseif exists("b:" . a:var_to_read)
        return get( b:, a:var_to_read, a:0 ? a:1 : '' )
    else
        6PrintSmart ·• Warning «Get…» •· →→ non-existent parameter given: ° s:tmp °
        return a:0 ? a:1 : ''
    endif
endfunc
" }}}
" FUNCTION: s:UserMenu_CleanupSesVars() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
function! s:UserMenu_CleanupSesVars(...)
    if has_key(s:,'user_menu_init_cmd_mode')
        call remove(s:,'user_menu_init_cmd_mode')
    endif
    if a:0 && a:1
        if has_key(s:,'user_menu_cmode_cmd')
            call remove(s:,'user_menu_cmode_cmd')
        endif
    endif
endfunc
" }}}
" FUNCTION: s:UserMenu_BufOrSesVarSet() {{{
" Returns b:<arg> or s:<arg>, if the 1st one doesn't exist.
function! s:UserMenu_BufOrSesVarSet(var_to_set, value_to_set)
    let s:tmp = a:var_to_set
    if exists("s:" . a:var_to_set)
        let s:[a:var_to_set] = a:value_to_set
    else
        if exists("b:" . a:var_to_set)
            let b:[a:var_to_set] = a:value_to_set
            return 1
        else
            6PrintSmart ·• Warning «Set…» •· →→ non-existent parameter given: ° s:tmp °
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
" FUNCTION: s:UserMenu_ExpandVars {{{
" It expands all {:command …'s} and {[sgb]:user_variable's}.
function! s:UserMenu_ExpandVars(text_or_texts)
    if type(a:text_or_texts) == v:t_list
        " List input.
        let texts=deepcopy(a:text_or_texts)
        let idx = 0
        for t in texts
            let texts[idx] = s:UserMenu_ExpandVars(t)
            let idx += 1
        endfor
        return texts
    elseif type(a:text_or_texts) == v:t_string
        " String input.
        return substitute(a:text_or_texts, '\v\{((:[^}]+|([svgb]\:|\&)[a-zA-Z_]
                        \[a-zA-Z0-9._]*%(\[[^]]+\])*))\}',
                        \ '\=((submatch(1)[0] == ":") ?
                        \ ((submatch(1)[1] == ":") ?
                        \ execute(submatch(1))[1:] :
                            \ execute(submatch(1))[1:0]) :
                                \ (exists(submatch(1)) ?
                                \ eval(submatch(1)) : submatch(1)))', 'g')
    else
        return a:text_or_texts
    endif
endfunc
" }}}
" FUNCTION: s:UserMenu_GetPrefixValue(pfx, msg) {{{
function! s:UserMenu_GetPrefixValue(pfx, msg)
    if a:pfx =~ '^[a-zA-Z]'
        let mres = matchlist( (type(a:msg) == 3 ? a:msg[0] : a:msg),'\v^(.{-})'.a:pfx.
                    \ ':([^:]*):(.*)$' )
    else
        let mres = matchlist( (type(a:msg) == 3 ? a:msg[0] : a:msg),'\v^(.{-})'.a:pfx.
                    \ '([0-9-]+\.=|[a-zA-Z0-9_-]*\.)(.*)$' )
    endif
    " Special case → a:msg is a List:
    " It's limited functionality — it doesn't allow to determine the message
    " part that preceded and followed the infix (it is just separated out).
    if type(a:msg) == 3 && !empty(mres)
        let cpy = deepcopy(a:msg)
        let cpy[0] = mres[1].mres[3]
        return [substitute(mres[2],'\.$','','g'),cpy,""]
    elseif !empty(mres)
        " Regular case → a:msg is a String
        " It returns the message divided into the part that preceded the infix
        " and that followed it.
        return [ substitute(mres[2],'\.$','','g'), mres[1], mres[3] ]
    else
        return [v:none,a:msg,""]
    endif
endfunc
" }}}
" FUNCTION: s:UserMenu_RestoreCmdLineFrom() {{{
function! s:UserMenu_RestoreCmdLine(timer)
    call filter( s:timers, 'v:val != a:timer' )
    call feedkeys(":\<C-U>".(s:UserMenu_BufOrSesVar("user_menu_cmode_cmd")[1:]),"ntxi!")
    call s:UserMenu_BufOrSesVarSet("user_menu_cmode_cmd", "")
    redraw
endfunc
" }}}

" FUNCTION: s:UserMenu_PauseAllTimers() {{{
function! s:UserMenu_PauseAllTimers(pause,time)
    for t in s:timers
        call timer_pause(t,a:pause)
    endfor

    if a:pause && a:time > 0
        " Limit the amount of time of the pause.
        call add(s:timers, timer_start(a:time, function("s:UserMenu_UnPauseAllTimersCallback")))
    endif
endfunc
" }}}
" FUNCTION: s:UserMenu_UnPauseAllTimersCallback() {{{
function! s:UserMenu_UnPauseAllTimersCallback(timer)
    call filter( s:timers, 'v:val != a:timer' )
    for t in s:timers
        call timer_pause(t,0)
    endfor
endfunc
" }}}
" FUNCTION: s:evalArg() {{{
function! s:evalArg(l,a,arg)
    call extend(l:,a:l)
    ""echom "ENTRY —→ dict:l °" a:l "° —→ dict:a °" a:a "°"
    " 1 — %firstcol.
    " 2 — whole expression, possibly (-l:var)
    " 3 — the optional opening paren
    " 4 — the optional closing paren
    " 5 — %endcol.
    let mres = matchlist(a:arg, '\v^(\%%([0-9-]+\.=|[a-zA-Z0-9_-]*\.))=(([(]=)-=[svbgla]:[a-zA-Z0-9._]+%(\[[^]]+\])*([)]=))(\%%([0-9-]+\.=|[a-zA-Z0-9_-]*\.))=$')
    " Not a variable-expression? → return the original string…
    if empty(mres) || mres[3].mres[4] !~ '^\(()\)\=$'
        "echom "Returning for" a:arg
        return a:arg
    endif
    " Separate-out the core-variable name and the sign.
    let no_dict_arg = substitute(mres[2], '^[(]\=\(-\=\)[svbgla]:\(.\{-}\)[)]\=$', '\1\2', '')
    "echom no_dict_arg "// 1"
    let sign = (no_dict_arg =~ '^-.*') ? -1 : 1
    if sign < 0
        let no_dict_arg = no_dict_arg[1:]
    endif
    "echom no_dict_arg "// 2"
    
    " Fetch the values — any variable-expression except for a:, where only
    " a:simple_forms are allowed, e.g.: no a:complex[s:form]…
    if mres[2] =~ '^(\=-\=a:.*'
        "echom "From-dict path ↔" no_dict_arg "—→" get(a:a, no_dict_arg, "<no-such-key>")
        if has_key(a:a, no_dict_arg)
            let value = get(a:a, no_dict_arg, "STRANGE-ERROR…")
            let value = sign < 0 ? -1*value : value
            return mres[1].value.mres[5]
        endif
    elseif exists(substitute(mres[2],'\v(^\(=-=|\)=$)',"","g"))
        "echom "From-eval path ↔" no_dict_arg "↔" eval(mres[2])
        " Via-eval path…
        let value = eval(mres[2])
        if type(value) != v:t_string
            let value = string(value)
        endif
        return mres[1].value.mres[5]
    endif
    " Fall-through path ↔ return of the original string.
    "echom "Fall-through path ↔" no_dict_arg "↔ dict:l °" a:l "° ↔ dict:a °" a:a "°"
    return a:arg
endfunc
" }}}
"""""""""""""""""" THE END OF THE HELPER FUNCTIONS }}}

"""""""""""""""""" UTILITY FUNCTIONS {{{

function! Messages2(arg=v:none)
    if a:arg == "clear"
        let g:messages = []
        return
    endif
    let s:Messages_state = 1
    for msg in g:messages
        call s:msg(msg[0],msg[1:])
    endfor
    let s:Messages_state = 0
endfunc
function! Flatten(list)
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
function! Mapped(fn, l)
    let new_list = deepcopy(a:l)
    call map(new_list, string(a:fn) . '(v:val)')
    return new_list
endfunc
function! Filtered(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, string(a:fn) . '(v:val)')
    return new_list
endfunc
function! FilteredNot(fn, l)
    let new_list = deepcopy(a:l)
    call filter(new_list, '!'.string(a:fn) . '(v:val)')
    return new_list
endfunc
function! CreateEmptyList(name)
    eval("let ".a:name." = []")
endfunc

"""""""""""""""""" THE END OF THE UTILITY FUNCTIONS }}}

"""""""""""""""""" THE SCRIPT BODY {{{
function! s:UserMenu_GetSDict()
    return s:
endfunct

augroup UserMenu_InitGroup
    au!
    au BufAdd * call s:UserMenu_InitBufAdd()
    au BufRead * call s:UserMenu_InitBufRead()
augroup END

exe "set previewpopup=height:".(&lines/2).",width:".(&columns/2-10)
inoremap <expr> <F2> UserMenu_Start("i")
nnoremap <expr> <F2> UserMenu_Start("n")
vnoremap <expr> <F2> UserMenu_Start("v")
cnoremap <F2> <C-\>eUserMenu_Start("c")<CR>
" Following doesn't work as expected…
onoremap <expr> <F2> UserMenu_Start("o")

" PrintSmart — echo-smart command.
command! -nargs=+ -count=4 -bang -bar -complete=expression PrintSmart call s:msgcmdimpl(<count>,<q-bang>,expand("<sflnum>"),
            \ map([<f-args>], 's:evalArg(exists("l:")?(l:):{},exists("a:")?(a:):{},v:val)' ))

" Messages command.
command! -nargs=? Messages call Messages(<q-args>)

" Menu command.
command! Menu call UserMenu_Start("n")

" Common highlight definitions.
hi! um_norm ctermfg=7
hi! um_blue ctermfg=27
hi! um_blue1 ctermfg=32
hi! um_blue2 ctermfg=75
hi! um_lblue ctermfg=50
hi! um_lblue2 ctermfg=75 cterm=bold
hi! um_lblue3 ctermfg=153 cterm=bold
hi! um_bluemsg ctermfg=123 ctermbg=25 cterm=bold
hi! um_gold ctermfg=220
hi! um_yellow ctermfg=190
hi! um_lyellow ctermfg=yellow cterm=bold
hi! um_lyellow2 ctermfg=221
hi! um_lyellow3 ctermfg=226
hi! um_green ctermfg=green
hi! um_green2 ctermfg=35
hi! um_green3 ctermfg=40
hi! um_green4 ctermfg=82
hi! um_bgreen ctermfg=green cterm=bold
hi! um_bgreen2 ctermfg=35 cterm=bold
hi! um_bgreen3 ctermfg=40 cterm=bold
hi! um_bgreen4 ctermfg=82 cterm=bold
hi! um_lgreen ctermfg=lightgreen
hi! um_lgreen2 ctermfg=118
hi! um_lgreen3 ctermfg=154
hi! um_lbgreen ctermfg=lightgreen cterm=bold
hi! um_lbgreen2 ctermfg=118 cterm=bold
hi! um_lbgreen3 ctermfg=154 cterm=bold

" A global, common timer-list for pausing…
let g:timers = exists("g:timers") ? g:timers : []

" Session-variables initialization.
let [ s:msgs, s:msg_idx ] = [ [], -1 ]
let s:state_restarting = 0
let s:last_pedit_file = ""
let s:last_jl_first_line = 0
let s:timers = g:timers
let s:jl_skip_count = 0
let s:main_skip_count = 0
let g:messages = []
let s:Messages_state = 0


