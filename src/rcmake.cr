# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "admiral"
require "colorize"
require "process"
require "yaml"

VERSION = "0.1.0"

GCC_LLD_LINK = "https://gcc.gnu.org/ml/gcc-patches/2016-07/msg00088.html"

DEFAULT_CONFIG = "~/.rcmake.yml"
DEFAULT_YAML = <<-YAML
# This is the default rcmake config file.

defaults:
  suite: clang
  generator: ninja
  linker: gold

  # Default C/C++/linker/CMake flags would go here:
  # cflags:
  #   - "-std=c99"
  # cxxflags:
  #   - "-std=c++11"
  # lflags:
  #   - "-rpath ."
  # cmakeflags:
  #   - "-DFOO=BAR"

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

YAML

RCMAKE_DESCRIPTION = <<-DESCR_END
rcmake is a wrapper over CMake designed to avoid having to constantly repeat
the same command-line arguments.
DESCR_END


macro auto_enum_methods(type)
  def {{type}}.new(sv : ::Admiral::StringValue)
    self.parse sv
  end

  def {{type}}.choices
    "(choices: #{self.names.map(&.downcase).join ", "})"
  end
end


class Config
  enum Generators
    Make
    Ninja

    def to_cmake
      case self
      when Make then "Unix Makefiles"
      when Ninja then "Ninja"
      else raise "Invalid generator #{self} in to_cmake"
      end
    end
  end


  enum Linkers
    BFD
    Gold
    LLD

    def to_cmake
      to_s.downcase
    end
  end


  enum BuildType
    Debug
    Release
    RelWithDebInfo
    MinSizeRel

    def to_cmake
      to_s
    end
  end


  auto_enum_methods Generators
  auto_enum_methods Linkers
  auto_enum_methods BuildType


  enum Flavor
    GCC
    Clang
  end


  class Defaults
    YAML.mapping suite: String, generator: Generators, linker: Linkers,
                 cflags: Array(String)?, cxxflags: Array(String)?,
                 lflags: Array(String)?, cmakeflags: Array(String)?
  end


  class Suite
    YAML.mapping c: String, cxx: String, flavor: Flavor
  end


  YAML.mapping defaults: Defaults, suites: Hash(String, Suite)
end


def fprint(kind, msg)
  color = case kind
    when :error then :red
    when :warning then :magenta
    when :note then :cyan
    else raise "Invalid color kind #{kind}"
  end

  with_color.bright.surround do
    puts "#{"[RCMAKE #{kind.to_s.upcase}]".colorize color} #{msg}"
  end
end


def die(msg)
  fprint :error, msg
  exit 1
end


class Rcmake < Admiral::Command
  define_version VERSION
  define_help description: RCMAKE_DESCRIPTION, short: h

  define_argument dir,
                  description: "The build directory to run CMake inside of",
                  required: true

  define_flag source,
              description: "The source directory",
              default: Dir.current,
              short: s

  define_flag cmake,
              description: "The cmake executable to use",
              default: "cmake",
              short: x

  define_flag gen : Config::Generators,
              description: "The generator to use #{Config::Generators.choices}",
              short: g

  define_flag config,
              description: "The config file to use",
              default: DEFAULT_CONFIG,
              short: f

  define_flag type : Config::BuildType,
              description: "The build type #{Config::BuildType.choices}",
              default: Config::BuildType::Debug,
              short: t

  define_flag suite,
              description: "The compiler suite to use",
              short: c

  define_flag linker : Config::Linkers,
              description: "The linker to use #{Config::Linkers.choices}",
              short: l

  define_flag cflag : Array(String),
              description: "Pass the given flag to the C compiler",
              short: C,
              default: [] of String

  define_flag cxxflag : Array(String),
              description: "Pass the given flag to the C++ compiler",
              short: X,
              default: [] of String

  define_flag lflag : Array(String),
              description: "Pass the given flag to the linker",
              short: L,
              default: [] of String

  define_flag cmakeflag : Array(String),
              description: "Pass the given flag to CMake",
              short: F,
              default: [] of String


  struct Arguments
    def initialize(command : ::Admiral::Command)
      command.attempt "Error parsing command-line arguments" { previous_def }
    end
  end


  def attempt(msg)
    begin
      yield
    rescue ex
      if msg
        die "#{msg}: #{ex}"
      else
        die ex.to_s
      end
    end
  end


  def parse_flags!(validate = false)
    attempt "Error parsing command-line arguments" { previous_def }
  end


  def get_cmake(given)
    if !(path = Process.find_executable given)
      die "Failed to locate '#{given}'"
    end
    path.not_nil!
  end


  def read_config(path)
    path = File.expand_path path

    if !File.exists? path
      if path == File.expand_path DEFAULT_CONFIG
        fprint :note, "Creating default config file in #{path}..."
        attempt "Error writing config file" do
          File.write path, DEFAULT_YAML
        end
      else
        die "Non-existent config file '#{path}'!"
      end
    end

    attempt "Error reading '#{path}'" do
      File.open path do |io|
        Config.from_yaml io
      end
    end
  end


  def get_suite(config, suite_name)
    suite_name ||= config.defaults.suite

    suite = config.suites[suite_name]?
    if suite
      suite
    else
      die "Non-existent suite '#{suite_name}'!"
    end
  end


  def setup_builddir(builddir)
    if File.exists? builddir
      if !File.directory? builddir
        die "Build directory '#{builddir}' isn't a directory!"
      end

      if !Dir.empty? builddir
        fprint :warning, "Build directory '#{builddir}' is not empty"
      else
        fprint :warning, "Build directory '#{builddir}' already exists"
      end
    else
      attempt "Error creating build directory '#{builddir}'" do
        Dir.mkdir_p builddir
      end
    end
  end


  def check_sourcedir(sourcedir)
    if !File.exists? sourcedir
      die "Source directory '#{sourcedir}' doesn't exist!"
    elsif !File.directory? sourcedir
      die "Source directory '#{sourcedir}' isn't a directory!"
    end
  end


  def quote_args(args)
    String.build do |io|
      args.each_with_index do |arg, i|
        io.print " " unless i == 0

        if arg == ""
          arg = "''"
        elsif arg =~ "[\s']"
          arg = "'#{arg.gsub "'", %q('"'"')}'"
        end
        io.print arg
      end
    end
  end


  def run_cmake(cmake, config, suite)
    builddir = arguments.dir
    sourcedir = flags.source
    gen = flags.gen || config.defaults.generator
    buildtype = flags.type
    ld = flags.linker || config.defaults.linker
    cflags = (config.defaults.cflags || [] of String) + flags.cflag
    cxxflags = (config.defaults.cxxflags || [] of String) + flags.cxxflag
    lflags = (config.defaults.lflags || [] of String) + flags.lflag
    cmakeflags = (config.defaults.cmakeflags || [] of String) + flags.cmakeflag
    args = [] of String

    setup_builddir builddir
    check_sourcedir sourcedir
    lflags.insert 0, "-fuse-ld=#{ld.to_cmake}"

    args.push File.expand_path sourcedir
    args.push "-G#{gen.to_cmake}"
    args.push "-DCMAKE_BUILD_TYPE=#{buildtype.to_cmake}"
    args.push "-DCMAKE_C_COMPILER=#{suite.c}"
    args.push "-DCMAKE_CXX_COMPILER=#{suite.cxx}"

    if suite.flavor == Config::Flavor::GCC && ld == Config::Linkers::LLD
      die "LLD can't be used with GCC (#{GCC_LLD_LINK})."
    end

    args.push "-DCMAKE_C_FLAGS=#{quote_args cflags}" if !cflags.empty?
    args.push "-DCMAKE_CXX_FLAGS=#{quote_args cxxflags}" if !cxxflags.empty?
    args.push "-DCMAKE_EXE_LINKER_FLAGS=#{quote_args lflags}"
    args.concat cmakeflags

    fprint :note, "Running: #{cmake} #{quote_args args}"

    attempt "Error spawning cmake" do
      Process.exec cmake, args, chdir: builddir
    end
  end


  def run
    cmake = get_cmake flags.cmake
    config = read_config flags.config
    suite = get_suite config, flags.suite

    run_cmake cmake, config, suite
  end
end

begin
  Rcmake.run
rescue ex
  fprint :error, ex.to_s
end
