require_relative 'program_env'
require 'readline'
require_relative 'line_editor'
out = ProgramEnv.new ""

loop do
  user_input = Editor.new("Shell> ").repl
  break if user_input.nil? || user_input == 'exit'
  out.get_input(user_input)
  out.lapis_eval
  if out.result.is_a? ProgramOutput
    puts out.result.output
  else
    puts out.result
  end
end
