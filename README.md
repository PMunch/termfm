# TermFM

To many people [eDEX-UI](https://github.com/GitSquared/edex-ui) was simply seen
as a joke UI, an experiment, or interactive art. But after watching a
demonstration of it I saw something that piqued my interest. Namely the file
manager that follows the terminal. It's one of the things that has sometimes
irked me while looking for a file. The `cd/ls/cd/ls/cd/ls` loop quickly gets
tedious. And opening my file manager, navigating to the folder I'm in, find the
thing I was looking for, and then copying the path back is even worse. So I
created this thing, TermFM, short for "Terminal File Manager". This is
currently in a PoC state, and only supports the basic premise of the idea. Here
is a YouTube video I recorded of how it works:

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/KoSbxQ_UlyA/0.jpg)](https://www.youtube.com/watch?v=KoSbxQ_UlyA)

## Setup
To make this work you need to add a little thing to you PS1:

``` bash
store_dir() {
  xprop -id $WINDOWID -f _CUSTOM_FOLDER 8s -set _CUSTOM_FOLDER $(pwd)
}

PS1='$(store_dir)' # For bash, you probably want to append/prepend it to what you have already
PROMPT='$(store_dir)' # For zsh, same as above
```

Then you can simply run TermFM whenever you want:
```
termfm $WINDOWID &
```

As you can see the program takes in the X11 window ID to read the property of
and direct the `xdotool type` command at. This obviously doesn't have to be the
terminal that launches TermFM, so you could easily have a keyboard shortcut that
just grabbed the current window (but maybe double check that it's actually a
terminal).

## TODO
Pretty much everything. Things that could be implemented, in no particular
order:

- Scrolling
- Options for fonts/icons
- Support the various file type colours
- Some kind of check if the terminal is ready for input
- Clear whatever is on the terminal input line before typing
- Different icons for different files
- Image previews
