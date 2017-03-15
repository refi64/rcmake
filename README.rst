rcmake
======

rcmake is a wrapper over CMake designed to avoid having to constantly repeat
the same command-line arguments.

If you feel like you're constantly doing stuff like this::

  mkdir build_dir
  cd build_dir
  cmake -G Ninja .. -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -D...

then rcmake is for you! Imagine all that being simplified to just::

  rcmake build_dir

Intrigued? Then read on!

Installation
************

::

  $ git clone https://github.com/kirbyfan64/rcmake.git
  $ cd rcmake
  $ shards build
  $ bin/rcmake ...

How-to
******

``rcmake`` greatly simplifies how you call CMake. In order to do so, it utilizes
a config file automatically created when you first run it (it's located at
``~/.rcmake.yml``).

Here's the most basic way to use rcmake::

  rcmake build_dir
  cd build_dir
  ninja

That's it! By default, rcmake will use Ninja as the generator target and Clang
as the compiler. Within rcmake, compilers are referred to as *suites*, which
consist of both the C compiler and the C++ compiler.

If you want to use make instead of Ninja, just run::

  rcmake build_dir -g make

``-g`` allows you to pick a different generator. Here, the *make* generator
(which corresponds to CMake's *Unix Makefiles* generator) is being used instead.

On the other hand, how about using GCC instead of Clang? You can do that pretty
easily::

  rcmake build_dir -c gcc

The ``-c`` options allows you to change the compiler suite rcmake uses. Here,
it's being changed to ``gcc``. (ZapCC is also supported.)

If you want a release build instead of debug, you can use::

  rcmake build_dir -t release

In addition, you can even change the linker from the default (gold) to LLD or
the classic BFD linker::

  rcmake build_dir -l bfd
  rcmake build_dir -l lld

What if there's an option rcmake doesn't cover? You can just pass it manually
using ``-C`` for C compiler flags, ``-X`` for C++ compiler flags, or ``-L`` for
linker flags::

  rcmake build_dir -C=-std=c99 -X=-std=c++11 -L=-B/usr/bin/ld.gold

You can even pass flags straight to CMake itself::

  rcmake build_dir -F=-DWHATEVER=123

The config file
***************

You can customize the default compiler suite and the different suites themselves
via the config file, ``~/.rcmake.yml``. By default, it looks like this:

.. code-block:: yaml

  # This is the default rcmake config file.

  default: clang

  suites:
    clang:
      c: clang
      cxx: clang++
      flavor: clang
    gcc:
      c: gcc
      cxx: g++
      flavor: gcc
    zapcc:
      c: zapcc
      cxx: zapcc++
      flavor: clang

If you want to change the default suite, just change the value of ``default``
to something else.

You can add suites, too. If you find yourself often cross-compiling for Windows,
you could add a suite like this:

.. code-block:: yaml

  suites:
    mingw:
      c: i686-w64-mingw32-gcc
      cxx: i686-w64-mingw32-g++
      flavor: gcc
    # ...

Command-line usage
******************

::

  Usage:
    /usr/local/bin/rcmake [flags...] <dir> [arg...]

  rcmake is a wrapper over CMake designed to avoid having to constantly repeat
  the same command-line arguments.

  Flags:
    --cflag, -C (default: [])                           # Pass the given flag to the C compiler
    --cmake, -x (default: cmake)                        # The cmake executable to use
    --cmakeflag, -F (default: [])                       # Pass the given flag to CMake
    --config, -f (default: ~/.rcmake.yml)               # The config file to use
    --cxxflag, -X (default: [])                         # Pass the given flag to the C++ compiler
    --gen, -g (default: Ninja)                          # The generator to use (choices: make, ninja)
    --help, -h (default: false)                         # Displays help for the current command.
    --lflag, -L (default: [])                           # Pass the given flag to the linker
    --linker, -l (default: Gold)                        # The linker to use (choices: bfd, gold, lld)
    --source, -s (default: /home/ryan/rcmake.cr/build)  # The source directory
    --suite, -c                                         # The compiler suite to use
    --type, -t (default: Debug)                         # The build type (choices: debug, release, relwithdebinfo, minsizerel)
    --version (default: false)

  Arguments:
    dir (required)                                      # The build directory to run CMake inside of

## Contributors

- `kirbyfan64 <https://github.com/kirbyfan64>`_ Ryan Gonzalez - creator, maintainer
