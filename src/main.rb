# frozen_string_literal: true

require_relative 'program_env'
require 'readline'

out = ProgramEnv.new ""

loop do
  user_input = Readline.readline('> ')
  break if user_input.nil? || user_input == 'exit'

  Readline::HISTORY.push(user_input)
  out.get_input(user_input)
  out.lapis_eval
  if out.result.is_a? ProgramOutput
    puts out.result.output
  else
    puts out.result
  end
end
