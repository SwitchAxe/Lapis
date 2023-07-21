# frozen_string_literal: true

require 'English'
require 'ripper'

def in_path?(str)
  `which #{str}`
  $CHILD_STATUS.success?
end

# The environment in which the shell execution takes place
class ProgramEnv
  def method_missing(method_name, *args)
    lapis_call_ext(method_name, args)
  end

  def respond_to_missing?(_method_name, *)
    true
  end

  def lapis_call_ext(pname, *pargs)
    s = ''
    raise "Unknown Executable #{pname}" unless in_path?(pname)

    argstr = pargs[0].inject('') { |a, c| "#{a} #{c}" }
    exect = pname.to_s + argstr
    IO.popen(exect, err: %i[child out]) { |ex| s += ex.read }
    s
  end

  def initialize(str)
    @str = str
  end

  def tokens(str)
    str.split.map { |s| s.split(';') }
       .flatten
       .map { |s| s.split('(') }
       .flatten
       .map { |s| s.split(')') }
       .flatten
  end

  def rewrite(tks)
    tks.map do |s|
      if s[0] == '-'
        # most likely a program argument
        "'#{s}'"
      else
        s
      end
    end
  end

  def reconcat(tks)
    tks.inject('') { |s, a| "#{s} #{a}" }
  end

  def lapis_eval
    instance_eval(reconcat(rewrite(tokens(@str))))
  end
end
