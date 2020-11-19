# Package

version       = "0.1.0"
author        = "Peter Munch-Ellingsen"
description   = "A simple file manager that mirrors what your terminal does"
license       = "MIT"
srcDir        = "src"
bin           = @["termfm"]


# Dependencies

requires "nim >= 1.4.0"
requires "imlib2"
requires "x11"
