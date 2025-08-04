# Copyright (c) 2023-2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.
# magic - Tcl bindings for libmagic (https://manned.org/libmagic.3).

# 29-Oct-2023  : v1.0   
               # Initial release.
# 02-Nov-2023  : v1.0.1 
               # Catching libmagic errors.
# 09-Dec-2023  : v1.0.2 
               # Replace tcl dictionaries by 'cffi::enum'.
               # Cosmetic changes.
# 15-Jun-2025  : v1.0.3
               # Raises the version of tcl-cffi to >= 2.0.
               # Try checking several places for the location of `libmagic` lib.
               # Tcl 9 supported.
# 04-Aug-2025 : v1.0.4
               # Enhanced cross-platform library search functionality.
               # The minimum supported libmagic version is now `5.45`.
               # Support for multiple versions of libmagic until `5.46`.
               # Adds `-path` option in arguments of constructor to load a specific magic database.
               # Windows support.

package require Tcl  8.6-
package require cffi 2.0

namespace eval magic {
    variable libmagicMinVersion 545
    variable version 1.0.4
    variable packageDirectory [file dirname [file normalize [info script]]]
    variable supportedMagicVersions [list 5.45 545 5.46 546]

    namespace export magic ; # export class

    proc load_magic {} {
        # Locates and loads the magic shared library
        #
        # Tries in order
        #   - the system default search path
        #   - platform specific subdirectories under the package directory
        #   - the toplevel package directory
        #   - the directory where the main program is installed
        # If all fail, simply tries the name as is in which case the
        # system will look up in the standard shared library search path.
        #
        # On success, creates the MAGIC cffi::Wrapper object in the global
        # namespace.

        variable packageDirectory
        variable supportedMagicVersions

        set magicPath {}
        # First make up list of possible shared library names depending
        # on platform and supported shared library versions.
        set ext [info sharedlibextension]
        if {$::tcl_platform(platform) eq "windows"} {
            # Names depend on compiler (mingw/vc). VC -> magic, mingw -> libmagic
            # Examples: magic.dll, libmagic.dll, magicVERSION.dll, magic-VERSION.dll
            foreach baseName {magic magic-1 libmagic} {
                foreach magicVersion $supportedMagicVersions {
                    lappend fileNames \
                        $baseName$magicVersion$ext \
                        $baseName-$magicVersion$ext
                }
                lappend fileNames $baseName$ext
            }
        } else {
            # Unix: libmagic.so, libmagicVERSION.so, libmagic-VERSION.so, libmagic.so.VERSION
            foreach magicVersion $supportedMagicVersions {
                lappend fileNames \
                    libmagic$magicVersion$ext \
                    libmagic.$magicVersion$ext \
                    libmagic-$magicVersion$ext
            }
            lappend fileNames libmagic$ext
        }

        set attempts {}

        # First try the system default search paths by no explicitly
        # specifying the full path
        foreach fileName $fileNames {
            if {![catch {
                cffi::Wrapper create ::MAGIC $fileName
            } err]} {
                return
            }
            append attempts $fileName : $err \n
        }

        # Not on default search path. Look under platform specific directories
        # under the package directory.
        package require platform
        set searchPaths [lmap platform [platform::patterns [platform::identify]] {
            if {$platform eq "tcl"} {
                continue
            }
            file join $packageDirectory $platform
        }]
        # Also look in package directory and location of main executable.
        # On Windows, the latter is probably redundant but...
        lappend searchPaths $packageDirectory
        lappend searchPaths [file dirname [info nameofexecutable]]
        # Specific case for macOS where the shared library is installed
        # under '/usr/local/lib'.
        if {$::tcl_platform(platform) eq "unix"} {
            set searchPaths [linsert $searchPaths 0 "/usr/local/lib"]
        }
        # Now do the actual search over search path for each possible name
        foreach searchPath $searchPaths {
            foreach fileName $fileNames {
                set path [file join $searchPath $fileName]
                if {![catch {
                    cffi::Wrapper create ::MAGIC $path
                } err]} {
                    return
                }
                append attempts $path : $err \n
            }
        }
        return -code error "Failed to load libmagic:\n$attempts"
    }
}

proc magic::error {callinfo} {
    # Magic error
    # 
    # callinfo - dictionary contains the information about call failure.
    #
    # Throws an error.
    if {[dict exists $callinfo In cookie]} {
        set cookie [dict get $callinfo In cookie]
        if {![cffi::pointer isnull $cookie]} {
            catch {magic_error $cookie} msg
            throw MAGIC_ERROR $msg
        }
    } else {
        if {[dict exists $callinfo Command]} {
            set cmd [dict get $callinfo Command]
        } else {
            set cmd "function"
        }

        if {[dict exists $callinfo Result]} {
            set result [dict get $callinfo Result]
        } else {
            set result "Error"
        }

        switch -exact -- $result {
            ""      {throw MAGIC_ERROR "Empty string returned from $cmd."}
            "-1"    {throw MAGIC_ERROR "Negative value returned from $cmd."}
            "NULL"  {throw MAGIC_ERROR "NULL pointer returned from $cmd."}
            "Error" {throw MAGIC_ERROR "Error MAGIC returned from $cmd."}
            default {throw MAGIC_ERROR "$result returned from $cmd."}
        }
    }
}

proc magic::flags {} {
    # Magic flags
    #
    # Returns magic flags dictionary.
    dict set flags MAGIC_NONE              0x0000000 ; # No flags
    dict set flags MAGIC_DEBUG             0x0000001 ; # Turn on debugging
    dict set flags MAGIC_SYMLINK           0x0000002 ; # Follow symlinks
    dict set flags MAGIC_COMPRESS          0x0000004 ; # Check inside compressed files
    dict set flags MAGIC_DEVICES           0x0000008 ; # Look at the contents of devices
    dict set flags MAGIC_MIME_TYPE         0x0000010 ; # Return the MIME type
    dict set flags MAGIC_CONTINUE          0x0000020 ; # Return all matches
    dict set flags MAGIC_CHECK             0x0000040 ; # Print warnings to stderr
    dict set flags MAGIC_PRESERVE_ATIME    0x0000080 ; # Restore access time on exit
    dict set flags MAGIC_RAW               0x0000100 ; # Don't convert unprintable chars
    dict set flags MAGIC_ERROR             0x0000200 ; # Handle ENOENT etc as real errors
    dict set flags MAGIC_MIME_ENCODING     0x0000400 ; # Return the MIME encoding
    dict set flags MAGIC_MIME              [expr {[dict get $flags MAGIC_MIME_TYPE] | 
                                                  [dict get $flags MAGIC_MIME_ENCODING]
                                            }]
    dict set flags MAGIC_APPLE             0x0000800 ; # Return the Apple creator/type
    dict set flags MAGIC_EXTENSION         0x1000000 ; # Return a /-separated list of
    dict set flags MAGIC_COMPRESS_TRANSP   0x2000000 ; # Check inside compressed files
    dict set flags MAGIC_NO_COMPRESS_FORK  0x4000000 ; # Don't allow decompression that
    dict set flags MAGIC_NODESC            [expr {[dict get $flags MAGIC_EXTENSION] | 
                                                  [dict get $flags MAGIC_APPLE]
                                            }]
    dict set flags MAGIC_NO_CHECK_COMPRESS 0x0001000 ; # Don't check for compressed files
    dict set flags MAGIC_NO_CHECK_TAR      0x0002000 ; # Don't check for tar files
    dict set flags MAGIC_NO_CHECK_SOFT     0x0004000 ; # Don't check magic entries
    dict set flags MAGIC_NO_CHECK_APPTYPE  0x0008000 ; # Don't check application type
    dict set flags MAGIC_NO_CHECK_ELF      0x0010000 ; # Don't check for elf details
    dict set flags MAGIC_NO_CHECK_TEXT     0x0020000 ; # Don't check for text files
    dict set flags MAGIC_NO_CHECK_CDF      0x0040000 ; # Don't check for cdf files
    dict set flags MAGIC_NO_CHECK_CSV      0x0080000 ; # Don't check for CSV files
    dict set flags MAGIC_NO_CHECK_TOKENS   0x0100000 ; # Don't check tokens
    dict set flags MAGIC_NO_CHECK_ENCODING 0x0200000 ; # Don't check text encodings
    dict set flags MAGIC_NO_CHECK_JSON     0x0400000 ; # Don't check for JSON files
    dict set flags MAGIC_NO_CHECK_SIMH     0x0800000 ; # Don't check for SIMH tape files
    dict set flags MAGIC_NO_CHECK_FORTRAN  0x000000  ; # Don't check ascii/fortran
    dict set flags MAGIC_NO_CHECK_TROFF    0x000000  ; # Don't check ascii/troff

    return $flags
}

# Try checking several places.
magic::load_magic

cffi::alias load C

# Enum magic flags.
cffi::enum define MagicFlags [magic::flags]

# Enum magic paramaters
cffi::enum sequence MagicParam {
    MAGIC_PARAM_INDIR_MAX
    MAGIC_PARAM_NAME_MAX
    MAGIC_PARAM_ELF_PHNUM_MAX
    MAGIC_PARAM_ELF_SHNUM_MAX
    MAGIC_PARAM_ELF_NOTES_MAX
    MAGIC_PARAM_REGEX_MAX
    MAGIC_PARAM_BYTES_MAX
    MAGIC_PARAM_ENCODING_MAX
    MAGIC_PARAM_ELF_SHSIZE_MAX
}

# Alias
cffi::alias define MAGIC_COOKIE     {pointer.COOKIE  {onerror magic::error}}
cffi::alias define MAGIC_INT_STATUS {int nonnegative {onerror magic::error}}
cffi::alias define MAGIC_STR_STATUS {string          {onerror magic::error}}
cffi::alias define MAGIC_ERR_STATUS {string errno}
cffi::alias define MAGIC_PARAM      {int             {enum MagicParam}}
cffi::alias define MAGIC_FLAGS      {int bitmask     {enum MagicFlags} {default MAGIC_NONE}}

# Functions from magic.h
MAGIC functions {
    magic_open       MAGIC_COOKIE     {flags MAGIC_FLAGS}
    magic_close      void             {cookie MAGIC_COOKIE}
    magic_getpath    MAGIC_STR_STATUS {filename {string nullifempty} i {int {default 0}}}
    magic_file       MAGIC_STR_STATUS {cookie MAGIC_COOKIE filename string}
    magic_descriptor MAGIC_STR_STATUS {cookie MAGIC_COOKIE fd int}
    magic_buffer     MAGIC_STR_STATUS {cookie MAGIC_COOKIE buffer string len size_t}
    magic_error      MAGIC_ERR_STATUS {cookie MAGIC_COOKIE}
    magic_getflags   MAGIC_INT_STATUS {cookie MAGIC_COOKIE}
    magic_setflags   MAGIC_INT_STATUS {cookie MAGIC_COOKIE flags MAGIC_FLAGS}
    magic_version    int              {}
    magic_load       MAGIC_INT_STATUS {cookie MAGIC_COOKIE filename {string nullifempty}}
    magic_compile    MAGIC_INT_STATUS {cookie MAGIC_COOKIE filename {string nullifempty}}
    magic_check      MAGIC_INT_STATUS {cookie MAGIC_COOKIE filename {string nullifempty}}
    magic_list       MAGIC_INT_STATUS {cookie MAGIC_COOKIE filename {string nullifempty}}
    magic_errno      MAGIC_INT_STATUS {cookie MAGIC_COOKIE}
    magic_setparam   MAGIC_INT_STATUS {cookie MAGIC_COOKIE param MAGIC_PARAM value {size_t inout}}
    magic_getparam   MAGIC_INT_STATUS {cookie MAGIC_COOKIE param MAGIC_PARAM value {size_t out}}
}

# Gets magic version.
set libversion [magic_version]

if {$libversion < $::magic::libmagicMinVersion} {
    error "libmagic version '$libversion' is unsupported.\
           Minimum version supported '$::magic::libmagicMinVersion'"
}

if {$libversion > [lindex $::magic::supportedMagicVersions end]} {
    error "libmagic version '$libversion' is unsupported.\
           Maximum version supported '[lindex $::magic::supportedMagicVersions end]'"
}

oo::class create magic::magic {

    variable _cookie ; # magic cookie

    constructor {args} {
        # Initializes a new magic Class.
        #
        # args - Options described below.
        # lflags     - list flags (see MagicFlags enum).
        # '-path XX' - path to specify the database.
        #
        # The function magic_open() returns a magic cookie on success and NULL on
        # failure setting errno to an appropriate value. It will set errno to EINVAL
        # if an unsupported value for flags was given.
        set lflags {}
        set path {}
        for {set i 0} {$i < [llength $args]} {incr i} {
            set value [lindex $args $i]
            switch -exact -- $value {
                "-path" {
                    incr i
                    if {$i < [llength $args]} {
                        set path [lindex $args $i]
                    }
                }
                default {
                    set lflags $value
                }
            }
        }

        if {![llength $lflags]} {
            set _cookie [magic_open] ; # default MAGIC_NONE
        } else {
            set _cookie [magic_open $lflags]
        }

        # Function must be used to load the colon separated list of
        # database files passed in as filename, or NULL for the default database file
        # before any magic queries can performed.
        # The default database file is named by the MAGIC environment variable. If
        # that variable is not set, the default database file name is
        # /usr/share/file/misc/magic.  magic_load() adds “.mgc” to the database
        # filename as appropriate.
        set loadmgc {}
        # Try to load the environment variable first if '-path' is not set.
        if {[info exists ::env(MAGIC)] && ($path eq "")} {
            set loadmgc $::env(MAGIC)
        }
        
        # If exists load database according to -path arg.
        if {$path ne ""} {
            set loadmgc $path
        }

        # Load default database.
        if {$loadmgc eq ""} {
            set loadmgc [magic_getpath "" 1]
        }

        try {
            magic_load $_cookie $loadmgc
        } trap MAGIC_ERROR {msg} {
            my destroy
            error "MAGIC_ERROR : magic_load '$msg'"
        } on error {result options} {
            error [dict get $options -errorinfo]
        }
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
        } trap MAGIC_ERROR {msg} {
            my destroy
            error "MAGIC_ERROR : '$msg'"
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
        } trap MAGIC_ERROR {msg} {
            my destroy
            error "MAGIC_ERROR : '$msg'"
        } on error {result options} {
            error [dict get $options -errorinfo]
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
        } trap MAGIC_ERROR {msg} {
            my destroy
            error "MAGIC_ERROR : '$msg'"
        } on error {result options} {
            error [dict get $options -errorinfo]
        }
    }

    method setFlags {lflags} {
        # Sets the flags.
        # 
        # lflags - list flags (see MagicFlags enum).
        #
        # Returns nothing or an error if flags is not knowed.
        try {
            magic_setflags [my cookie] $lflags
        } trap MAGIC_ERROR {msg} {
            my destroy
            error "MAGIC_ERROR : '$msg'"
        } on error {result options} {
            error [dict get $options -errorinfo]
        }
    }

    method getParam {param} {
        # Gets limits related to the magic library.
        #
        # param - name paramater (see MagicParam enum)
        #
        # Returns value
        try {
            magic_getparam [my cookie] $param value
        } trap MAGIC_ERROR {msg} {
            my destroy
            error "MAGIC_ERROR : '$msg'"
        } on error {result options} {
            error [dict get $options -errorinfo]
        }

        return $value
    }

    method setParam {param value} {
        # Sets limits related to the magic library.
        #
        # param - name paramater (see MagicParam enum)
        # value - int 
        #
        # Returns nothing
        try {
            magic_setparam [my cookie] $param value
        } trap MAGIC_ERROR {msg} {
            my destroy
            error "MAGIC_ERROR : '$msg'"
        } on error {result options} {
            error [dict get $options -errorinfo]
        }

        return {}
    }

    method close {} {
        # See destructor.
        my destroy
    }

    destructor {
        # Closes the magic database and deallocates any
        # resources used and destroy oo object.
        if {![cffi::pointer isnull [my cookie]]} {
            magic_close [my cookie]
        }
    }
}

# Import class.
namespace import magic::magic

package provide magic $::magic::version