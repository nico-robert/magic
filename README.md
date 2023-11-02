magic
================
Tcl bindings for [libmagic](https://manned.org/libmagic.3).   

Tested on Mac OS X, should be working on Linux.

Dependencies :
-------------------------
- [Tcl cffi](https://cffi.magicsplat.com) >= 1.0

Prerequisites :
-------------------------
- On Mac OS X: `brew install libmagic`

Example :
-------------------------
```tcl
package require magic

# Sets a new instance of magic class with optional flag(s).
set mg [magic new] ; # Note we can combine flags. See all flags for more info. Default flag 'MAGIC_NONE'
$mg fromFile "path/to/file/magic.pdf" ; # > PDF document, version 1.3, 1 page(s)

# Sets a new flag (note we can combine flags).
$mg setFlags MAGIC_EXTENSION
$mg fromFile "path/to/file/magic.pdf" ; # > pdf

# Sets a new instance of magic class with MAGIC_MIME_TYPE flag.
set mg [magic new MAGIC_MIME_TYPE]

set fp   [open "path/to/file/magic.pdf" rb]
set data [read $fp 2048]
close $fp

# Buffer data.
$mg fromBuffer $data ; # > application/pdf

# Combined the flags.
set mg [magic new {MAGIC_MIME_TYPE MAGIC_MIME_ENCODING}]
$mg fromFile "path/to/file/magic.jpeg" ; # > image/jpeg; charset=binary
```

License :
-------------------------
**magic** is covered under the terms of the [MIT](LICENSE) license.

Release :
-------------------------
*  **29-Oct-2023** : 1.0
    - Initial release.
*  **02-Nov-2023** : 1.0.1
    - Catching libmagic errors.