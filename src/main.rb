# frozen_string_literal: true

require_relative 'program_env'

prog = ProgramEnv.new 'puts(ls -al)'

prog.lapis_eval
