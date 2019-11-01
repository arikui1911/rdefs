require 'optparse'

class Rdefs
  class Preprocessor
    def initialize(f)
      @f = f
    end

    def gets
      line = @f.gets
      if begin_line?(line)
        while line = @f.gets
          break if end_line?(line)
        end
        line = @f.gets
      end
      line
    end

    def lineno
      @f.lineno
    end

    private

    def begin_line?(line)
      return false unless line
      return false unless line.start_with?('=begin')
      Util.space? line['=begin'.size, 1]
    end

    def end_line?(line)
      return false unless line
      return false unless line.start_with?('=end')
      Util.space? line['=end'.size, 1]
    end
  end

  module Util
    module_function

    SPACES = [" ", "\t", "\r", "\n", "\f", "\v"]

    def space?(c)
      SPACES.include? c
    end

    WORDS = [*('a'..'z'), *('A'..'Z'), *('0'..'9'), '_']

    def word_component?(c)
      WORDS.include? c
    end
  end

  def initialize
    @def_method = :def_beginning_line?
    @print_line_number_p = false
    @f = Preprocessor.new(ARGF)
    parse_options
  end

  def parse_options
    options = OptionParser.new do |opt|
      opt.banner = "#{File.basename($0)} [-n] [file...]"
      opt.on('--class', 'Show only classes and modules') {
        @def_method = :class_def_beginning_line?
      }
      opt.on('-n', '--lineno', 'Prints line number.') {
        @print_line_number_p = true
      }
      opt.on('--help', 'Prints this message and quit.') {
      puts opt.help
        exit 0
      }
    end

    begin
      options.parse!
    rescue OptionParser::ParseError => err
      $stderr.puts err.message
      exit 1
    end
  end

  def process
    while line = @f.gets
      if send(@def_method, line)
        printf '%4d: ', @f.lineno if @print_line_number_p
        print getdef(line, @f)
      end
    end
  end

  def getdef(str, f)
    until balanced?(str)
      line = f.gets
      break unless line
      str << line
    end
    str
  end

  def balanced?(str)
    s = str.gsub(/'.*?'/, '').gsub(/".*?"/, '')
    s.count('(') == s.count(')')
  end

  private

  DEFS = ['def', 'class', 'module', 'include', 'alias',
          'attr_reader', 'attr_writer', 'attr_accessor', 'attr',
          'public', 'private', 'protected', 'module_function']

  def def_beginning_line?(line)
    line = line.lstrip
    w = DEFS.detect{|w| line.start_with?(w) } or return false
    c = line[w.size, 1]
    case w
    when 'def', 'class', 'module'
      return true if Util.space?(c)
    when 'include', 'attr_reader', 'attr_writer', 'attr_accessor', 'attr',
         'public', 'private', 'protected', 'module_function'
      return true unless Util.word_component?(c)
    when 'alias'
      return true unless Util.word_component?(c)
      return false unless c == '_'
      rest = line[w.size+1..-1]
      n = rest.each_char.take_while{|c| Util.word_component?(c) }.size
      return false unless n > 1
      return true unless Util.word_component?(rest[n, 1])
    end
    false
  end

  CLASS_DEFS = ['class', 'module', 'include']

  def class_def_beginning_line?(line)
    line = line.lstrip
    w = CLASS_DEFS.detect{|w| line.start_with?(w) } or return false
    c = line[w.size, 1]
    return true if Util.space?(c)
    return true if w == 'include' && c == '('
    false
  end
end
