require_relative 'program_env'
require 'bundler/setup'

require 'tty-cursor'
require 'tty-reader'
require 'tty-prompt'
require 'pastel'
require 'pp'
$ttycursor = TTY::Cursor
$ttyreader = TTY::Reader
$ttypastel = Pastel.new
class Prompt
  def initialize()
    @prompt = TTY::Prompt.new
    @result = ""
  end

  def show(options)
    print $ttycursor.save
    print $ttycursor.down(1)
    if options.size == 0 then
      @result = nil
    else
      @result = @prompt.select("Choose an entry", options, cycle: true)
    end
  end
  def get = @result
end


class Selection
  def initialize(prefix)
    @pfx = prefix
    @rx = /^#{Regexp.quote(@pfx)}/
    @options = []
  end

  def choices
    result = Dir.glob("**/*", File::FNM_DOTMATCH)
    @options = result.select {|x| @rx.match? x}
    return @options
  end
end


class Colorize
  def initialize(input)
    @tks = Tokens.new(input).get
    @result = @tks.map do |tk|
      if in_path?(tk) or method?(tk) then
        $ttypastel.magenta(tk)
      elsif to_integer(tk) != nil then
        $ttypastel.yellow(tk)
      elsif strlit?(tk) then
        $ttypastel.green(tk)
      else tk
      end
    end
    @result = @result.inject('', &:+)
  end

  def get = @result
  
end

class Keypress
  def initialize()
    @p = 0
    @in = nil
    @right_lim = 0
  end

  def goto_endline() @p = @right_lim end
  
  def resize_limit(n) @right_lim = n end
  def set(str)
    if str == "\t" then
      @in = nil
    elsif str == "\r" then # newline
      @in = nil
      @p = 0
    elsif str == "\e[D" then # left
      if @p > 0 then
        print $ttycursor.backward(1)
        @in = nil
        @p -= 1
      end
    elsif str == "\e[C" then # right
      if @p < @right_lim then
        print $ttycursor.forward(1)
        @in = nil
        @p += 1
      end
    elsif str == "\e[A" then # up
      @in = nil
    elsif str == "\e[B" then # down
      @in = nil
    elsif str == "\x7F" then # backspace
      @p -= 1 if @p > 0
      @right_lim -= 1
      @in = nil
    else
      print $ttycursor.forward(1)
      @in = str
      @p += 1
      @right_lim += 1
    end
  end
  def getp = @p
  def get = @in
end

class Editor
  def initialize(pr, hist)
    @ttyreader = TTY::Reader.new
    @prompt = Prompt.new
    @user_prompt = pr
    @ttyreader.on(:keyctrlx) { exit }
    @input = ""
    @input_bak = ""
    @last_word = ""
    @history = hist
    @history_index = 0
    @must_return = false
    @key = Keypress.new
    @ttyreader.on(:keybackspace) do
      pos = @key.getp
      begin
        @input.slice!(pos - 1)
        print $ttycursor.save
        print $ttycursor.clear_line
        print @user_prompt + Colorize.new(@input).get
        print $ttycursor.restore
        print $ttycursor.backward(1)
        STDOUT.flush
        if @input == "" then @last_word = ""
        elsif @input[-1] == ' ' then @last_word = ""
        else @last_word = @input[0..pos].split.last
        end
        if @last_word[0] == '"' then @last_word = @last_word[1, -1] end
        if @last_word == nil then @last_word = "" end
      end if pos > 0
    end
    @ttyreader.on(:keytab) do
      @prompt.show(Selection.new(@last_word).choices)
      if @prompt.get == nil then
        print $ttycursor.save
        print $ttycursor.scroll_down
        print $ttycursor.row(0)
        print $ttycursor.column(0)
        print $ttycursor.clear_line
        print $ttypastel.red "No completions available!\n"
        print $ttycursor.restore
        STDOUT.flush
      else
        for i in 1..@last_word.length do
          @input = @input.chop
        end
        @input += "\"#{@prompt.get}\""
        @key.resize_limit(@input.length)
        @key.goto_endline
        print $ttycursor.column(0)
        print $ttycursor.clear_line
        print @user_prompt + Colorize.new(@input).get
        STDOUT.flush
      end
    end

    # history up
    @ttyreader.on(:keyup) do
      if @history_index >= @history.size then
        print $ttycursor.save
        print $ttycursor.scroll_down
        print $ttycursor.row(0)
        print $ttycursor.column(0)
        print $ttycursor.clear_line
        print $ttypastel.red "End of history!\n"
        print $ttycursor.restore
        STDOUT.flush
      else
        @input_bak = @input if @history_index == 0
        @input = @history[@history.length - @history_index - 1]
        @history_index += 1
        print $ttycursor.save
        print $ttycursor.clear_line
        print $ttycursor.column(0)
        print @user_prompt + Colorize.new(@input).get
        print $ttycursor.down(1)
        print $ttycursor.column(0)
        print $ttypastel.green "History entry ##{@history_index}"
        print $ttycursor.restore
        @key.resize_limit(@input.length)
        STDOUT.flush
      end
    end

    @ttyreader.on(:keydown) do
      if @history_index == 0 then
        print $ttycursor.save
        print $ttycursor.scroll_down
        print $ttycursor.row(0)
        print $ttycursor.column(0)
        print $ttycursor.clear_line
        print $ttypastel.red "End of history!\n"
        print $ttycursor.restore
        STDOUT.flush
      elsif @history_index == 1 then
        @history_index = 0
        @input = @input_bak
      else
        @history_index -= 1
        @input = @history[@history.length - @history_index - 1]
      end
      print $ttycursor.save
      print $ttycursor.clear_line
      print $ttycursor.column(0)
      print @user_prompt + Colorize.new(@input).get
      print $ttycursor.down(1)
      print $ttycursor.column(0)
      print $ttypastel.green "History entry ##{@history_index}"
      print $ttycursor.restore
      @key.resize_limit(@input.length)
      STDOUT.flush
    end
    
    @ttyreader.on(:keyreturn, :keyenter) do
      print $ttycursor.down(1)
      print $ttycursor.column(0)
      print $ttycursor.clear_line
      STDOUT.flush
      @must_return = true
      @history_index = 0
    end
  end

  def repl()
    print @user_prompt
    STDOUT.flush
    loop do
      @key.set(@ttyreader.read_char(echo: false))
      k = @key.get
      if @must_return then return @input end
      print $ttycursor.save
      print $ttycursor.clear_line
      print $ttycursor.column(0)
      STDOUT.flush
      @input.insert(@key.getp - 1, k) if k != nil
      @last_word += k if k != nil
      if k == ' ' then @last_word = "" end
      print @user_prompt + Colorize.new(@input).get
      print $ttycursor.restore
      STDOUT.flush
    end
    return nil
  end
end
