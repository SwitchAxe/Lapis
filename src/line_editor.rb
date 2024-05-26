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
    @prompt.on(:keytab) {|_k| @prompt.trigger(:keydown) }
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
    result = ProgramEnv.new("ls -1")
    result.lapis_eval()
    result = result.result.output
    xs = result.split("\n")
    @options = xs.select {|x| @rx.match? x}
    return @options
  end
end


class Colorize
  def initialize(input)
    @tks = Tokens.new(input).get
    @result = @tks.map do |tk|
      if $special.include? tk then
        $ttypastel.cyan(tk)
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
    @right_lim = 0
  end

  def goto_endline() @p = @right_lim end
  
  def resize_limit(n) @right_lim = n end
  def set(str)
    if str == "\e[D" then # left
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
  def initialize(pr)
    @ttyreader = TTY::Reader.new
    @prompt = Prompt.new
    @user_prompt = pr
    @ttyreader.on(:keyctrlx) { exit }
    @input = ""
    @last_word = ""
    @must_return = false
    @key = Keypress.new
    @special_keys = ["\t", nil]
    @ttyreader.on(:keybackspace) do
      pos = @key.getp
      @input.slice!(pos - 1)
      print $ttycursor.backward(1)
      print $ttycursor.clear_line
      print @user_prompt + Colorize.new(@input).get
      STDOUT.flush
    end
    @ttyreader.on(:keytab) do
      @prompt.show(Selection.new(@last_word).choices)
      if @prompt.get == nil then
        print $ttycursor.save
        print $ttycursor.scroll_down
        print $ttycursor.row(0)
        print $ttycursor.column(0)
        print $ttypastel.red "\nNo completions available!"
        print $ttycursor.restore
        print $ttycursor.backward(1)
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
        # STDOUT.flush
        # print $ttycursor.clear_screen_down
        STDOUT.flush
      end
    end
    @ttyreader.on(:keyreturn, :keyenter) do
      print $ttycursor.down(1)
      print $ttycursor.column(0)
      STDOUT.flush
      @must_return = true
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
      @input.insert(@key.getp - 1, k) if not @special_keys.include? k
      @last_word += k if not @special_keys.include? k
      if k == ' ' then @last_word = "" end
      print @user_prompt + Colorize.new(@input).get
      print $ttycursor.restore
      STDOUT.flush
    end
    return nil
  end
  
end
