#
# Add specific improved functionality
#
class HighLineExtension < HighLine
  [:ask, :agree].each do |sym|
    define_method(sym) do |*args, &block|
      separate_blocks
      super(*args, &block)
    end
  end

  # OVERRIDE
  def say(msg)
    separate_blocks

    Array(msg).each do |statement|
      statement = statement.to_str
      next unless statement.present?

      template  = ERB.new(statement, nil, "%")
      statement = template.result(binding)

      statement = wrap(statement) unless @wrap_at.nil?
      statement = send(:page_print, statement) unless @page_at.nil?

      @output.print(indentation) unless @last_line_open

      @last_line_open = 
        if statement[-1, 1] == " " or statement[-1, 1] == "\t"
          @output.print(statement)
          @output.flush
        else
          @output.puts(statement)
        end
    end

    msg
  end

  # given an array of arrays "items", construct an array of strings that can
  # be used to print in tabular form.
  def table(items, opts={}, &block)
    items = items.map &block if block_given?
    widths = []
    items.each do |item|
      item.each_with_index do |s, i|
        item[i] = s.to_s
        widths[i] = [widths[i] || 0, item[i].length].max
      end
    end
    align = opts[:align] || []
    join = opts[:join] || ' '
    if opts[:header]
      opts[:header].each_with_index do |s, i|
        widths[i] = [widths[i] || 0, s.length].max
      end
      sep = opts[:separator] || "="
      ary = Array.new(opts[:header].length)
      items.unshift ary.each_with_index {|obj, idx| ary[idx] = sep.to_s * (widths[idx] || 1)}
      items.unshift(opts[:header])
    end
    if w = opts[:width]
      allocate = 
        if w.is_a? Array
          w[widths.length] = nil
          w[0,widths.length]
        else
          columns = widths.length
          used = w - join.length * (columns-1)
          extra = used % columns
          base = used / columns
          Array.new(columns){ base + ((used -= 1) >= 0 ? 1 : 0) }
        end

      fmt = allocate.zip(align).map{ |s, al| "%#{al == :right ? '' : '-'}#{s}s" }.join(join)
      items.inject([]) do |a,item| 
        r = item.zip(allocate).map{ |column,w| w ? column.textwrap_ansi(w, false) : [column] }
        #binding.pry
        r.map(&:length).max.times do |i|
          a << fmt % r.map{ |row| row[i] }
        end
        a
      end
    else
      items.map do |item|
        item.each_with_index.map{ |s,i| s.send((align[i] == :right ? :rjust : :ljust), widths[i], ' ') }.join(join).rstrip
      end
    end
  end


  def header(str,opts = {}, &block)
    str = underline(str)
    str = str.map{ |s| color(s, opts[:color]) } if opts[:color]
    say str
    if block_given?
      indent &block
    end
  end

  def underline(s)
    [s, "-"*s.length]
  end

  #:nocov:
  # Backport from Highline 1.6.16
  unless HighLine.method_defined? :indent
    #
    # Outputs indentation with current settings
    #
    def indentation
      return ' '*@indent_size*@indent_level
    end

    #
    # Executes block or outputs statement with indentation
    #
    def indent(increase=1, statement=nil, multiline=nil)
      @indent_level += increase
      multi = @multi_indent
      @multi_indent = multiline unless multiline.nil?
      if block_given?
          yield self
      else
          say(statement)
      end
    ensure
      @multi_indent = multi
      @indent_level -= increase
    end
  end 
  #:nocov:

  ##
  # section
  #
  # highline helper mixin which correctly formats block of say and ask
  # output to have correct margins.  section remembers the last margin
  # used and calculates the relitive margin from the previous section.
  # For example:
  #
  # section(bottom=1) do
  #   say "Hello"
  # end
  #
  # section(top=1) do
  #   say "World"
  # end
  #
  # Will output:
  #
  # > Hello
  # >
  # > World 
  #
  # with only one newline between the two.  Biggest margin wins.
  #
  # params:
  #  top - top margin specified in lines
  #  bottom - bottom margin specified in line
  #
  def section(params={}, &block)
    top = params[:top] || 0
    bottom = params[:bottom] || 0

    # the first section cannot take a newline
    top = 0 unless @margin
    @margin = [top, @margin || 0].max

    value = block.call

    say "\n" if @last_line_open
    @margin = [bottom, @margin].max

    value
  end

  ##
  # paragraph
  #
  # highline helper which creates a section with margins of 1, 1
  #
  def paragraph(&block)
    section(:top => 1, :bottom => 1, &block)
  end

  # Some versions of highline get in an infinite loop when trying to wrap.
  # Fixes BZ 866530.
  # OVERRIDE
  def wrap_line(line)
    wrapped_line = []
    i = chars_in_line = 0
    word = []

    while i < line.length
      # we have to give a length to the index because ruby 1.8 returns the
      # byte code when using a single fixednum index
      c = line[i, 1]
      color_code = nil
      # escape character probably means color code, let's check
      if c == "\e"
        color_code = line[i..i+6].match(/\e\[\d{1,2}m/)
        if color_code
          # first the existing word buffer then the color code
          wrapped_line << word.join.wrap(@wrap_at) << color_code[0]
          word.clear

          i += color_code[0].length
        end
      end

      # visible character
      if !color_code
        chars_in_line += 1
        word << c

        # time to wrap the line?
        if chars_in_line == @wrap_at
          if c == ' ' or line[i+1, 1] == ' ' or word.length == @wrap_at
            wrapped_line << word.join
            word.clear
          end

          wrapped_line[-1].rstrip!
          wrapped_line << "\n"

          # consume any spaces at the begining of the next line
          word = word.join.lstrip.split(//)
          chars_in_line = word.length

          if line[i+1, 1] == ' '
            i += 1 while line[i+1, 1] == ' '
          end

        else
          if c == ' '
            wrapped_line << word.join
            word.clear
          end
        end

        i += 1
      end
    end

    wrapped_line << word.join
    wrapped_line.join
  end

  def wrap(text)
    wrapped_text = []
    lines = text.split(/\r?\n/)
    lines.each_with_index do |line, i|
      wrapped_text << wrap_line(i == lines.length - 1 ? line : line.rstrip)
    end

    wrapped_text.join("\n")
  end

  private
    def separate_blocks
      if (@margin ||= 0) > 0 && !@last_line_open
        @output.print "\n" * @margin
        @margin = 0
      end
    end
end

$terminal = HighLineExtension.new