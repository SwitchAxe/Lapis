require_relative 'program_env'
require 'readline'
require_relative 'line_editor'
out = ProgramEnv.new ""

prompt = ""
config_file = ENV['HOME'] + "/.config/lapis/config.rb"
if File.exist?(config_file) then
   prompt_env = ProgramEnv.new(File.read config_file)
   prompt_env.lapis_eval
   if prompt_env.result.is_a? ProgramOutput
     prompt = prompt_env.result.output
   else
     prompt = prompt_env.result
   end
 end

loop do
  user_input = Editor.new(prompt).repl
  break if user_input.nil? || user_input == 'exit'
  out.get_input(user_input)
  out.lapis_eval
  if out.result.is_a? ProgramOutput
    puts out.result.output
  else
    puts out.result
  end
end
