# Copyright (c) 2023 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.
# magic - Tcl bindings for libmagic (https://manned.org/libmagic.3).

package ifneeded magic 1.0.1 [list apply {dir {
    source [file join $dir magic.tcl]
}} $dir]