# frozen_string_literal: true

require 'English'
require 'ripper'
require 'pp'

def in_path?(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

def to_integer(string)
  num = string.to_i
  return num if num.to_s == string
  nil
end

def strlit?(str)
    if (str[0] == '"') and (str[str.length() - 1] == '"') then
      return true
  end
  false
end

def method?(str)
  begin
    method(str)
    return true
  rescue
    return false
  end
end
  
# global array of operators AND keywords in the
# ruby language. DO NOT MODIFY THIS!!!!!
$special = ['(', ')', '{', '}',
            ' ', '+', '-', '/',
            '*', '**', '%', '>>',
            '<<', '&', '|', '~',
            '&&', '||', '?', ':',
            '^', '!', '<', '<=',
            '>', '>=', '==', '===',
            '!=', '=~', '!~', '<=>',
            '..', '...', 'rescue', '=',
            '**=', '*=', '/=', '%=',
            '+=', '-=', '<<=', '>>=',
            '&&=', '&=', '||=', '|=',
            '^=', 'defined?', 'not', 'and',
            'or', 'if', 'else', 'elsif',
            'while', 'until', 'for', 'in',
            'begin', 'end', 'BEGIN', 'END',
            'alias', 'break', 'case', 'class',
            'def', 'do', 'ensure', 'module',
            'next', 'nil', 'redo', 'retry',
            'return', 'self', 'super', 'then',
            'undef', 'when', 'yield', 'ENCODING',
            'LINE', 'FILE', '#', '.',
            ';']

# pipe implementation
def pipe(input, *proc2)
  # We use the fact that 'spawn' doesn't use a shell when
  # arguments are provided.
  r, w = IO.pipe
  w.write(input)
  r2, w2 = IO.pipe
  spawn(*proc2, in: r, out: w2)
  w.close
  r.close
  w2.close
  res = r2.readlines.inject('', &:+)
  r2.close
  res
end

# Program output to pipe into other processes using
# method chaining
class ProgramOutput
  def initialize(out)
    @out = out
  end

  def method_missing(method_name, *args, &block)
    unless @out.respond_to?(method_name)
      ret = ProgramOutput.new(pipe(@out, method_name.to_s,
                                   *args.map(&:to_s)))
      maybe_blr = block&.call(ret)
      # if maybe_blr (blr == block return) is nil, return ret.
      # otherwise, return maybe_blr.
      return maybe_blr if maybe_blr
      return ret
    end
    met = @out.method(method_name)
    res = met.call(*args)
    ret = block&.call(res)
    return ret if ret
    res
  end

  def respond_to_missing?(_any, *)
    true
  end

  def output = @out
end

def lapis_call_ext(pname, *pargs)
  s = ''
  raise "Unknown Executable #{pname}" unless in_path?(pname)
  
  argstr = pargs[0].inject('') { |a, c| "#{a} #{c}" }
  exect = pname.to_s + argstr
  IO.popen(exect, err: %i[child out]) { |ex| s += ex.read }
  ProgramOutput.new(s)
end


class Tokens
  def initialize(str)
    @str = str
    @tks = []
    tmp = ''
    in_str = false
    @str.chars do |c|
      if c == "-"
        tmp += "-"
        
      elsif $special.include?(c) and !in_str
        @tks << tmp unless tmp.empty?
        @tks << c
        tmp = ''
      elsif c == '"'
        tmp += '"'
        in_str = !in_str
        begin
          @tks << tmp
          tmp = ''
        end if in_str == false 
      else
        tmp += c
      end
    end
    @tks << tmp unless tmp.empty?
  end
  
  def get = @tks
end

class Format
  def initialize(tks, vars)
    @tks = tks
    @result = ""
    @vars = vars
    rewrite
    reconcat
  end

  def rewrite()
    last_word = ""
    last_word_quoted = false
    last_word_command = false
    @tks = @tks.map.with_index do |x, i|
      if (x == ' ') then x
      elsif i == 0 then
        last_word = x;
        last_word_command = true if in_path?(x)
        x
      elsif in_path?(last_word) || method?(last_word) then
        if $special.include? x then
          last_word = x
          x
        elsif strlit? x then x
        elsif x[0] == "-" then
          last_word = "'#{x}'"
          last_word_quoted = true
          "'#{x}'"
        else
          last_word = x
          x
        end
      elsif (!in_path?(x)) && (!method?(x)) then
        if x[0] == "-" then
          if ($special.include? last_word) || ($special.include? x) then
            last_word = x
            x
          else
            last_word = ", '#{x}'"
            last_word_quoted = true
            last_word
          end
        else
          last_word = x
          x
        end
      else
        last_word = x
        last_word_quoted = false
        last_word_command = true if in_path? x
        x
      end
    end
  end
  
  def reconcat()
    return "" if @tks.size == 0
    @tks[-1] = @tks[-1][0..-2] if @tks[-1][-1] == ','
    @result = @tks
                .map {|s| if @vars.has_key?(s) then "@vars[\"#{s}\"]" else s end }
                .inject('', &:+)
  end
  def get = @result
end

# The environment in which the shell execution takes place
class ProgramEnv
  def method_missing(method_name, *args, &block)
    a = lapis_call_ext(method_name, args)
    b = block&.call(a.output)
    return b if b
    a
  end

  def respond_to_missing?(_method_name, *)
    true
  end

  def initialize(str)
    @str = str
    @vars = {} # an hashmap
    @result = ""
  end

  def get_input(str)
    @str = str
  end

  def assignment?(str)
    /[[:alnum:]]+[[:space:]]*=[[:space:]]*.*/.match(str) != nil
  end

  def get_assignment(str)
    tks = Tokens.new(str).get
    id = tks[0]
    while (tks[0] != "=") do tks.shift() end
    tks.shift()
    tks = Tokens.new(@str).get
    fmt = Format.new(tks, @vars).get
    val = instance_eval(fmt)
    @vars[id] = val
  end
  
  def lapis_eval
    if assignment? @str then
      get_assignment(@str)
      @result = nil
    else
      tks = Tokens.new(@str).get
      fmt = Format.new(tks, @vars).get
      @result = instance_eval(fmt)
    end
  end
  def result = @result
end
