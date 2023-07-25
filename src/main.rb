# frozen_string_literal: true

require_relative 'program_env'
require 'readline'

loop do
  user_input = Readline.readline('> ')
  break if user_input.nil? || user_input == 'exit'

  Readline::HISTORY.push(user_input)
  out = (ProgramEnv.new user_input).lapis_eval
  if out.is_a? ProgramOutput
    puts out.output
  else
    puts out
  end
end
