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
            'LINE', 'FILE', '#', '.', ',',
            ';', '[', ']']

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
      maybe_blr = block&.call(ret.output)
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

def lapis_call_ext(pname, pargs)
  s = ''
  raise "Unknown Executable #{pname}" unless in_path?(pname)
  pargs.unshift(pname.to_s)
  pargs = pargs.map {|x| x.to_s}
  IO.popen(pargs, :err=>[:child, :out]) { |ex| s += ex.read }
  ProgramOutput.new(s)
end

class Tokens
  def initialize(str)
    @str = str
    @tks = []
    tmp = ''
    in_str = false
    in_pipes = false
    @str.chars.each_with_index do |c, i|
      if c == "-"
        tmp += "-"
      elsif c == " " and (!in_str) and (!in_pipes) then
        @tks << tmp unless tmp.empty?
        @tks << " "
        tmp = ""
      elsif c == "|" then
        begin
          @tks << tmp
          tmp = ""
        end unless tmp.empty? or tmp[0] == "|"
        tmp += '|'
        in_pipes = !in_pipes
        begin
          @tks << tmp
          tmp = ''
        end if in_pipes == false
      elsif $special.include?(@str[i]) and (!in_str) and (!in_pipes) and
            ((i == (@str.length - 1)) or (i == 0) or
             ((@str[i+1] == ' ') || (@str[i-1] == ' '))) then
        @tks << tmp unless tmp.empty?
        @tks << c
        tmp = ""
      elsif c == '"'
        begin
          @tks << tmp
          tmp = ""
        end unless tmp.empty? or tmp[0] == "\""
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
    past_first_arg = false
    in_command = false
    must_insert_command = false
    new_tks = []
    in_block = false
    @tks.each_with_index do |x, i|
      if (x == ' ') then new_tks << x
      elsif (x == '{') || (x == 'do') then
        in_block = true
        new_tks << ")" if in_command
        new_tks << x
      elsif in_block then
        in_block = false
        if x[0] == '|' then
          must_insert_command = true
          new_tks << x
        else
          if in_path?(x) or method?(x) then
            in_command = true
            past_first_arg = false
            new_tks << x
            new_tks << "("
          else
            new_tks << x
            in_command = false
            must_insert_command = false
          end
        end
      elsif i == 0 then
        if in_path?(x) or method?(x) then
          in_command = true
          new_tks << x
          new_tks << "("
        else new_tks << x
        end
      elsif must_insert_command then
        if in_path?(x) or method?(x) then
          new_tks << x
          new_tks << "("
          in_command = true
          past_first_arg = false
          must_insert_command = false
        else
          new_tks << x
          must_insert_command = false
          in_command = false
        end
      elsif (x == ".") and in_command then
        new_tks << ")"
        new_tks << "."
        past_first_arg = false
        must_insert_command = true
      elsif $special.include? x then
        if in_command then
          new_tks << ")"
          new_tks << x
          in_command = false
          past_first_arg = false
        else new_tks << x
        end
      else
        if in_command then
          if past_first_arg then
            new_tks << ","
            if @vars.has_key? x then new_tks << "@vars[\"#{x}\"]"
            elsif (to_integer(x) != nil) or strlit? x then new_tks << x
            elsif (x == "true") or (x == "false") then new_tks << x
            else new_tks << "\"#{x}\""
            end
          else
            past_first_arg = true
            if @vars.has_key? x then new_tks << "@vars[\"#{x}\"]"
            elsif (to_integer(x) != nil) or strlit? x then new_tks << x
            elsif (x == "true") or (x == "false") then new_tks << x
            else new_tks << "\"#{x}\""
            end
          end
        else new_tks << x
        end
      end
    end
    @tks = new_tks
    if in_command and new_tks[-1][0] != ")" then
      @tks << ")"
    end
  end
  
  def reconcat()
    return "" if @tks.size == 0
    @tks[-1] = @tks[-1][0..-2] if @tks[-1][-1] == ','
    @result = @tks.inject('', &:+)
  end
  def get = @result
end

# The environment in which the shell execution takes place
class ProgramEnv
  require 'bundler/setup'
  require 'pastel' # for the config file
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
    /[[:alnum:]]+[[:space:]]*=[[:space:]]*.*/.match(str).to_s == str
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
