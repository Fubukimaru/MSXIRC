# MSXIRC

MSXIRC v1.1 by DucaSP
**Only for MSX2 or superior**

This version has been modified and updated. Also, now it is compiled using SJASM

Original code by Ptero, based on Konamiman's TCPcon. This code can be found in
original_code folder. Originally assembled with AS80.

Special thanks to Ptero for making the code and for allowing us to share it.


# User manual (extracted from MSXIRC.HLP)

Use navigations buttons [UP] [DOWN] to scroll this help screen

## Work anywhere:

- [ESC] - Invoke Main Menu / Last Window Opened
- [F1]  - Show this help screen

## In Main Menu:

- [S] - Invoke Server Console Window
- [Q] - Return to MSX-DOS
- [UP][DOWN] - Navigate the Window list (if any)
- [ENTER] - Enter the Window selected

## In Server Console Window:

- [F2] - Connect to server
- [F3] - Disconect
- [&] - Send again NICK , PASS and USER messages and SERVERPASS if configured
- Join IRC channel: /JOIN #channel
- Private MSG: /QUERY username

## Work on any Window you input text (Channel, Query, Server)

- [SHIFT]+[UP], [SHIFT+DOWN] to scroll pages
- [CTRL]+[UP], [CTRL+DOWN] to go up/down a single line (in this case line is not
    related to a screen line, but a line of text from server or keyboard input)
- [CLS] - Go to the last line of text in the screen
- [INS] - Alternate insertion mode
- [CTRL]+[LEFT], [CTRL]+[RIGHT] - Switch Windows
- [LEFT][RIGHT] - Navigate the text type highlighting the selected character
- [DEL] - Delete character selected
- [BS] - Delete character to the left of selected char
- [CTRL] + [Q] - Close the current Window (except Server Console Window)

## In Channel Window

- [F2] - Allow you to navigate the nick list, enter will copy the name in the
       text input line
- [SELECT] - Same as F2
- Private Message - /QUERY username OR, type /QUERY and space, then hit F2 or
SELECT, choose the nick and hit enter (once to copy the nick and twice to open
the query/private message window)


## Configuration file

This client will connect only to a single server. You can open up to 80 Windows
(channel, server console, private message), as long as your MSX has enough
free segments in the memory mapper. For each window a 16KB memory segment is
allocated. So, the maximum number of Windows opened is limited by how many free
16KB segments your computer has (i.e.: MSX-DOS2 uses one, UNAPI Memory Mapper
driver another, a 128KB machine has 4 segments for main ram, 1 segment for 
MSX-DOS2 and 1 segment to the UNAPI driver, leaving 2 free segments).

To change server and color settings, edit MSXIRC.INI, or, create different .INI
files for each server you want to use. When executing MSXIRC, if no parameter
is given, it will try to use MSXIRC.INI file to load configurations, but you
can use any .INI file you want, i.e.: FREENODE.INI as a file to connect to
FREENODE, so you execute MSXIRC as follow: MSXIRC FREENODE.INI

The following items are read from the .INI file:

- server - the server name / address to connect to
- port - the port for the server connection
- srvpass - password for the server
- nick - your desired nickname
- altnick - alternative nickname
- user - the user information reported to the server
- font - which alternative font file to use
- ink_c - color for regular text (0-15)
- paper_c - color for regular background (0-15)
- aink_c - color for text selected / on cursor(0-15)
- apaper_c - color for cursor or lower bar highlight (0-15)
- timestamp - Enable time-stamp on text windows as follow:
    + 0 - Disabled
    + 1 - HH:MM
    + 2 - HH:MM:SS
    + 3 - MM.YY HH:MM
    + 4 - MM.YY HH:MM:SS
    + 5 - DD.MM.YY HH:MM
    + 6 - DD.MM.YY HH:MM:SS

# Changelog

## v1.1 - Release by Oduvaldo Pavan Junior

- Fixes to the UNAPI calling code so it works with ROM UNAPI's
- Fixes not being able to connect to server when using a INI file as input
  parameter
- Fixes DOS1 Mapper support when no mapper present
- DOS1 Mapper wouldn't allow usage of #FF segment for our program, it a valuable
  segment, one more window and no reason to do so
- Fixes possible crash with DOS1 mapper support and Mapper UNAPI, it was
  assuming it always use last mapper segment in DOS1, this is not a rule even
  though it works for Obsonet that does that :)
- Changed the exit function, so it closes open connection as well
- Updated so the main menu won't show remainings of the cursor or of the SIAT :)
- Improvement on the Help File
- Text strings review / correction
- Clean-up of code
- Commentaries about code functionality
       
