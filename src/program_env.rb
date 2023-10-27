# frozen_string_literal: true

require 'English'
require 'ripper'

def in_path?(str)
  `which #{str}`
  $CHILD_STATUS.success?
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
  end

  def tokens(str)
    tks = []
    tmp = ''
    in_str = false
    str.chars do |c|
      if $special.include?(c) and !in_str
        tks << tmp unless tmp.empty?
        tks << c
        tmp = ''
      elsif c == '"'
        tmp += '"'
        in_str = !in_str
        begin
          tks << tmp
          tmp = ''
        end if in_str == false 
      else
        tmp += c
      end
    end
    tks << tmp unless tmp.empty?
    tks
  end

  def maybe_quote(str)
    if str[0] == "'"
      str
    else
      "'#{str}'"
    end
  end

  def rewrite(tks)
    must_insert_comma = false
    tks
      .filter { |s| s != '' }
      .map do |s|
      if $special.include?(s) || (s[0] == '"')
        must_insert_comma = false
        s
      elsif must_insert_comma && !$specials.include?(s)
        " #{maybe_quote(s)},"
      else
        must_insert_comma = true
        s
      end
    end
  end

  def reconcat(tks)
    return "" if tks.size == 0
    tks[-1] = tks[-1][0..-2] if tks[-1][-1] == ','
    tks.inject('', &:+)
  end

  def lapis_eval
    instance_eval(reconcat(rewrite(tokens(@str))))
  end
end
