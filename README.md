# MSXIRC

MSXIRC v1.1 by DucaSP
**Only for MSX2 or superior**

This version has been modified and updated. Also, now it is compiled using SJASM

Original code by Ptero, based on Konamiman's TCPcon. This code can be found in
original_code folder. Originally assembled with AS80.

Special thanks to Ptero for making the code and for allowing us to share it.


# User manual


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
       
