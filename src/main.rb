require_relative 'program_env'
require 'readline'
require_relative 'line_editor'
out = ProgramEnv.new ""

prompt = ""
config_dir = ENV['HOME'] + "/.config/lapis/"
config_file = config_dir + "config.rb"
history_file = config_dir + ".history"
if File.exist? config_file then
  prompt_env = ProgramEnv.new(File.read config_file)
  prompt_env.lapis_eval
  if prompt_env.result.is_a? ProgramOutput
    prompt = prompt_env.result.output
  else
    prompt = prompt_env.result
  end
end

if not File.exist? history_file then
  tmp = File.new(history_file, File::CREAT | File::RDWR)
  tmp.close
end
new_history = File.read(history_file).split("\n")
loop do
  begin
    user_input = Editor.new(prompt, new_history).repl
    new_history << user_input if user_input != nil
    break if user_input.nil? || user_input == 'exit'
    out.get_input(user_input)
    out.lapis_eval
    if out.result.is_a? ProgramOutput
      puts out.result.output
    else
      puts out.result
    end
  rescue => ex
    puts "Exception:"
    puts ex.full_message(highlight: true, order: :top)
  end
end

tmp = File.open(history_file, File::APPEND | File::WRONLY) do |fd|
  fd.write(new_history.map {|s| s + "\n"}.inject("", &:+))
end
