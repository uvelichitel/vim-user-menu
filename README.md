# Vim User Menu

Sometimes it doesn't fit right to add another function or command for yet
another code snippet spotted on GitHub or a Wiki. Drawbacks of such approach
include:

1. It's easy to forget about the snippets saved in such a way.
2. … or to forget the way that they should be used.
3. A sense of disorder might gradually arise when a larger number of such
   snippets will be stored and forgotten…

## Proposed alternative → a pop-up User Menu

An alternate approach is being proposed and implemented with this Vim plugin
— to gather the snippets as *entries in a pop-up user menu*. Benefits of such
approach:

1. The snippets aren't lost from the sight of the user, hence they cannot be
   forgotten.
2. There's no sense of disorder gradually arising, as there's no dark-area of
   vimrc that's growing.
3. It's a new, more advanced level of storage of Vim code/commands.
4. It might be cool to for a difference *select* something in Vim, rather than
   to invoke a keystroke-command.

## Presentations

Main features by the example of the default menu:

[![asciicast](https://asciinema.org/a/354759.svg)](https://asciinema.org/a/354759)

The feature — ability to edit the command line:

[![asciicast](https://asciinema.org/a/354825.svg)](https://asciinema.org/a/354825)

The two advanced provided functionalities — the buffer- and jump-list popup menus:

[![asciicast](https://asciinema.org/a/356128.svg)](https://asciinema.org/a/356128)

## Usage

The default binding is **`<F12>`** — pressing it will open the **default**,
**example** menu presented in the above Asciicasts.

The default menu consists of multiple provided entries, which are being called
the "*menu kit*". You can reuse the kit's entries when building your own menu,
as described below.

### Your own menu (entries…)

```vim
" The 4 types of menu items:
let g:user_menu = [
        \ [ "Item 1", #{ type: 'cmds', body: "sequence of :ex commands" } ],
        \ [ "Item 2", #{ type: 'norm', body: ":norm sequence of commands" } ],
        \ [ "Item 3", #{ type: 'keys', body: "sequence of keys like e.g.: \<C-W>n" } ],
        \ [ "Item 4", #{ type: 'expr', body: "the expression to run, like e.g.: MyFunction()" } ]
\ ]

" How to reuse the default's menu items — the menu kit:
let g:user_menu = [
   \     "KIT:buffers",                                             " The buffer list
   \     [ "List buffers", "KIT:buffers"],                          " The buffer list under an non-standard name
   \     #{ name:"List buffers", kit:"buffers", opts:"in-visual"}   " An alternate syntax
\ ]
```

The menu-kit entries are: **buffers**, **jumps**, **open**, **save**,
**save-all-quit**, **toggle-vichord-mode**, **toggle-auto-popmenu**,
**new-win**, **visual-to-subst-escaped**, **visual-yank-to-subst-escaped**,
**capitalize**, **escape-cmd-line**,

<!-- vim:set tw=80 autoindent fo+=a1n: --> 
