# Copyright (c) 2023 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.
# magic - Tcl bindings for libmagic (https://manned.org/libmagic.3).

# 29-Oct-2023  : v1.0  Initial release

package require Tcl  8.6
package require cffi 1.0

namespace eval magic {
    variable libname         "libmagic"
    variable libmagicversion 545
    variable version         1.0
}

proc magic::error {callinfo} {
    # Magic error
    # 
    # callinfo - dictionary contains the information about call failure.
    #
    # Returns nothing
    if {[dict exists $callinfo In cookie]} {
        set cookie [dict get $callinfo In cookie]
        if {![cffi::pointer isnull $cookie]} {
            throw MAGIC_ERROR [magic_error $cookie]
        }
    } else {
        if {[dict exists $callinfo Command]} {
            set cmd [dict get $callinfo Command]
        } else {
            set cmd "function"
        }

        if {[dict exists $callinfo Result]} {
            set result [dict get $callinfo Result]
            switch -exact -- $result {
                ""      {throw MAGIC_ERROR "Empty string returned from $cmd."}
                -1      {throw MAGIC_ERROR "Negative value returned from $cmd."}
                NULL    {throw MAGIC_ERROR "NULL pointer returned from $cmd."}
                default {throw MAGIC_ERROR "$result returned from $cmd."}
            }
        }
    }

    return {}
}

proc magic::flags {dict flags} {
    # Magic error
    # 
    # dict  - constants magic.h
    # flags - list flags
    #
    # Returns a list containing the values.
    set listF {}
    foreach key $flags {
        if {![dict exists $dict $key]} {
            error "'$key' MAGIC FLAG is not supported."
        }
        set value [dict get $dict $key]
        if {![string is integer -strict $value]} {
            append listF " [magic::flags $dict $value]"
            continue
        }
        lappend listF $value
    }

    return $listF
}

# Loading the library .
if {[catch {
    cffi::Wrapper create MAGIC $::magic::libname-$::magic::libmagicversion[info sharedlibextension]
}]} {
    # Could not find the version-labeled library.
    # Load without version.
    cffi::Wrapper create MAGIC $::magic::libname[info sharedlibextension]
}

cffi::alias load C

# Alias
cffi::alias define MAGIC_COOKIE     {pointer.COOKIE  {onerror magic::error}}
cffi::alias define MAGIC_INT_STATUS {int nonnegative {onerror magic::error}}
cffi::alias define MAGIC_STR_STATUS {string          {onerror magic::error}}

# Functions from magic.h
MAGIC stdcalls {
    magic_open       MAGIC_COOKIE     {flags int}
    magic_close      void             {cookie MAGIC_COOKIE}
    magic_getpath    MAGIC_STR_STATUS {filename {string nullifempty} i {int {default 0}}}
    magic_file       MAGIC_STR_STATUS {cookie MAGIC_COOKIE filename string}
    magic_descriptor MAGIC_STR_STATUS {cookie MAGIC_COOKIE fd int}
    magic_buffer     MAGIC_STR_STATUS {cookie MAGIC_COOKIE buffer string len size_t}
    magic_error      string           {cookie MAGIC_COOKIE}
    magic_getflags   MAGIC_INT_STATUS {cookie MAGIC_COOKIE}
    magic_setflags   MAGIC_INT_STATUS {cookie MAGIC_COOKIE flags int}
    magic_version    int              {}
    magic_load       MAGIC_INT_STATUS {cookie MAGIC_COOKIE filename {string nullifempty}}
    magic_compile    MAGIC_INT_STATUS {cookie MAGIC_COOKIE filename {string nullifempty}}
    magic_check      MAGIC_INT_STATUS {cookie MAGIC_COOKIE filename {string nullifempty}}
    magic_list       MAGIC_INT_STATUS {cookie MAGIC_COOKIE filename {string nullifempty}}
    magic_errno      MAGIC_INT_STATUS {cookie MAGIC_COOKIE}
    magic_setparam   MAGIC_INT_STATUS {cookie MAGIC_COOKIE param int value {size_t inout}}
    magic_getparam   MAGIC_INT_STATUS {cookie MAGIC_COOKIE param int value {size_t out}}
    
}

# Gets magic version.
set libversion [magic_version]

if {$libversion < $::magic::libmagicversion} {
    error "libmagic version '$libversion' is unsupported.\
           Minimum version supported '$::magic::libmagicversion'"
}

oo::class create magic {

    variable _cookie ; # magic cookie
    variable _flags  ; # magic flags
    variable _params ; # magic paramaters

    constructor {{list ""}} {
        # Initializes a new magic Class.
        #
        # list - See flags below.
        #
        dict set _flags MAGIC_NONE              0x0000000 ; # No flags
        dict set _flags MAGIC_DEBUG             0x0000001 ; # Turn on debugging
        dict set _flags MAGIC_SYMLINK           0x0000002 ; # Follow symlinks
        dict set _flags MAGIC_COMPRESS          0x0000004 ; # Check inside compressed files
        dict set _flags MAGIC_DEVICES           0x0000008 ; # Look at the contents of devices
        dict set _flags MAGIC_MIME_TYPE         0x0000010 ; # Return the MIME type
        dict set _flags MAGIC_CONTINUE          0x0000020 ; # Return all matches
        dict set _flags MAGIC_CHECK             0x0000040 ; # Print warnings to stderr
        dict set _flags MAGIC_PRESERVE_ATIME    0x0000080 ; # Restore access time on exit
        dict set _flags MAGIC_RAW               0x0000100 ; # Don't convert unprintable chars
        dict set _flags MAGIC_ERROR             0x0000200 ; # Handle ENOENT etc as real errors
        dict set _flags MAGIC_MIME_ENCODING     0x0000400 ; # Return the MIME encoding
        dict set _flags MAGIC_MIME              {MAGIC_MIME_TYPE MAGIC_MIME_ENCODING}
        dict set _flags MAGIC_APPLE             0x0000800 ; # Return the Apple creator/type
        dict set _flags MAGIC_EXTENSION         0x1000000 ; # Return a /-separated list of
        dict set _flags MAGIC_COMPRESS_TRANSP   0x2000000 ; # Check inside compressed files
        dict set _flags MAGIC_NO_COMPRESS_FORK  0x4000000 ; # Don't allow decompression that
        dict set _flags MAGIC_NODESC            {MAGIC_EXTENSION MAGIC_MIME MAGIC_APPLE}
        dict set _flags MAGIC_NO_CHECK_COMPRESS 0x0001000 ; # Don't check for compressed files
        dict set _flags MAGIC_NO_CHECK_TAR      0x0002000 ; # Don't check for tar files
        dict set _flags MAGIC_NO_CHECK_SOFT     0x0004000 ; # Don't check magic entries
        dict set _flags MAGIC_NO_CHECK_APPTYPE  0x0008000 ; # Don't check application type
        dict set _flags MAGIC_NO_CHECK_ELF      0x0010000 ; # Don't check for elf details
        dict set _flags MAGIC_NO_CHECK_TEXT     0x0020000 ; # Don't check for text files
        dict set _flags MAGIC_NO_CHECK_CDF      0x0040000 ; # Don't check for cdf files
        dict set _flags MAGIC_NO_CHECK_CSV      0x0080000 ; # Don't check for CSV files
        dict set _flags MAGIC_NO_CHECK_TOKENS   0x0100000 ; # Don't check tokens
        dict set _flags MAGIC_NO_CHECK_ENCODING 0x0200000 ; # Don't check text encodings
        dict set _flags MAGIC_NO_CHECK_JSON     0x0400000 ; # Don't check for JSON files
        dict set _flags MAGIC_NO_CHECK_SIMH     0x0800000 ; # Don't check for SIMH tape files
        dict set _flags MAGIC_NO_CHECK_FORTRAN  0x000000  ; # Don't check ascii/fortran
        dict set _flags MAGIC_NO_CHECK_TROFF    0x000000  ; # Don't check ascii/troff

        # Paramaters
        dict set _params MAGIC_PARAM_INDIR_MAX		0 
        dict set _params MAGIC_PARAM_NAME_MAX		1
        dict set _params MAGIC_PARAM_ELF_PHNUM_MAX	2
        dict set _params MAGIC_PARAM_ELF_SHNUM_MAX	3
        dict set _params MAGIC_PARAM_ELF_NOTES_MAX	4
        dict set _params MAGIC_PARAM_REGEX_MAX		5
        dict set _params MAGIC_PARAM_BYTES_MAX		6
        dict set _params MAGIC_PARAM_ENCODING_MAX	7
        dict set _params MAGIC_PARAM_ELF_SHSIZE_MAX	8

        if {![llength $list]} {
            set flags [dict get $_flags MAGIC_NONE]
        } else {
            set flags [expr [join [magic::flags $_flags $list] " | "]]
        }

        # The function magic_open() returns a magic cookie on success and NULL on
        # failure setting errno to an appropriate value.  It will set errno to EINVAL
        # if an unsupported value for flags was given.
        set _cookie [magic_open $flags]

        # Function must be used to load the colon separated list of
        # database files passed in as filename, or NULL for the default database file
        # before any magic queries can performed.
        # The default database file is named by the MAGIC environment variable.  If
        # that variable is not set, the default database file name is
        # /usr/share/file/misc/magic.  magic_load() adds “.mgc” to the database
        # filename as appropriate.
        magic_load $_cookie {}

    }

    method fromFile {file} {
        # self.fromFile
        #
        # file - filename
        #
        # Returns a textual description of the contents of
        # the filename argument, or NULL if an error occurred.
        try {
            magic_file [my cookie] $file
        } trap MAGIC_ERROR {} {
            $self destroy
        } on error {result options} {
            error [dict get $options -errorinfo]
        }
    }

    method fromBuffer {buffer} {
        # self.fromBuffer
        #
        # buffer - data
        #
        # Returns a textual description of the contents
        # of the buffer argument with length bytes size.
        try {
            magic_buffer [my cookie] $buffer [string length $buffer]
        } trap MAGIC_ERROR {} {
            $self destroy
        } on error {result options} {
            error [dict get $options -errorinfo]
        } finally {
            catch {close $fp}
        }
    }

    method cookie {} {
        # Returns magic cookie.
        return $_cookie
    }

    method getflags {} {
        # Returns a value representing current flags set.
        try {
            magic_getflags [my cookie]
        } trap MAGIC_ERROR {} {
            $self destroy
        } on error {result options} {
            error [dict get $options -errorinfo]
        }
    }

    method setFlags {list} {
        # Sets the flags.
        # 
        # list - list flags
        #
        # Returns nothing or an error if flags is sno
        try {
            set flags [expr [join [magic::flags $_flags $list] " | "]]
            magic_setflags [my cookie] $flags
        } trap MAGIC_ERROR {} {
            $self destroy
        } on error {result options} {
            error [dict get $options -errorinfo]
        }
    }

    method getParam {param} {
        # Gets limits related to the magic library.
        #
        # param - name paramater (see _param dictionnary)
        #
        # Returns value
        try {
            magic_getparam [my cookie] [dict get $_params $param] value
        } trap MAGIC_ERROR {} {
            $self destroy
        } on error {result options} {
            error [dict get $options -errorinfo]
        }

        return $value
    }

    method setParam {param value} {
        # Sets limits related to the magic library.
        #
        # param - name paramater (see _param dictionnary)
        # value - int 
        #
        # Returns nothing
        try {
            magic_setparam [my cookie] [dict get $_params $param] value
        } trap MAGIC_ERROR {} {
            $self destroy
        } on error {result options} {
            error [dict get $options -errorinfo]
        }

        return {}
    }

    method close {} {
        # Closes the magic database and deallocates any
        # resources used.
        magic_close [my cookie]
    }

    destructor {
        # See self.close
        magic_close $_cookie
    }
}

package provide magic $::magic::version