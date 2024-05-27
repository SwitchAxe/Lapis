# Lapis
## A GNU/Linux Shell built in the Ruby programming language.
It's designed to be feature-complete and with a syntax compatible with the default ruby one.

## What's implemented
- [x] Custom line editor
  * [x] Basic input navigation: backspace, arrow keys, enter
  * [x] Basic file completions using `ls`
  * [x] History navigation
- [x] Custom syntax parser
  * [x] Program calls
  * [x] Ruby languge interoperability (mixing programs and functions, etc)
  * [x] Blocks as arguments to programs

- [ ] Other/Wishlist
  * [x] A config file to store the prompt configuration
  * [ ] A way to extend or customize the line editor
  
## An example config file
Put this in  `/home/youruser/.config/lapis/config.rb` to get started.
```ruby
# this function is mandatory. you can optionally use any functions to aid in
# building this one, which MUST be present.
# this is just a prompt example, you can build it however  you want.
def prompt ()
  user = ENV['USER']
  host = ENV['HOSTNAME']
  "#{user}@#{host} => "
end

prompt
```

## Custom procedures
By default, Lapis is very minimal in what you can do with it, but since Lapis code is just
Ruby code with extra steps, you can actually use Ruby to customize Lapis and, in particular,
make custom functions. Lapis doesn't have a "cd" builtin, but we can quickly make a usual, and even better,
version:
```ruby
# the block is optional. If the block is given, cd will only affect the block.
# otherwise, it will change the directory globally and persistently, just like
# the bash 'cd' command.
# the block, if present, must accept NO arguments.
def cd(str)
  if block_given? then
    result = ""
    Dir.chdir(str) { result = yield }
    return result
  end
  Dir.chdir(str)
  nil
end
```  

Lapis will check for additional procedures like the one above only once per-session, so you can't
hot-reload them. These procedures will go in a `procedures.rb` file in `~/.config/lapis`.

## How to run the shell
provided you have the dependencies (the latest ruby version and bundler) you can run
the shell in two ways:
- (Recommended) use the startup script provided with the shell.
  - The instructions on how to use it can be found in the script itself.
- (Not recommended) just run `ruby src/main.rb` while in the project root dir.
  - This has the problem that you MUST be in the project root directory for it to work.
  - It will set the working directory to the project dir. If that's undesirable to you,
	use the first (preferred) option with the launch script.
  
# Warning
⚠️ **Some components of the parser might break unpredictably. Use at your own risk for now.**
