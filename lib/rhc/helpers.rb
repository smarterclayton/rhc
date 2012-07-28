require 'commander/user_interaction'
require 'rhc/config'
require 'rhc/commands'

OptionParser.accept(URI) {|s,| URI.parse(s) if s}

module RHC

  module Helpers
    private
      def self.global_option(*args)
        RHC::Commands.global_option *args
      end
  end

  module Helpers

    # helpers always have Commander UI available
    include Commander::UI
    include Commander::UI::AskForClass

    extend self

    global_option '--debug', "Write debug output"
    def debugging?
      options.debug
    end

    def decode_json(s)
      RHC::Vendor::OkJson.decode(s)
    end

    def date(s)
      now = Time.now
      d = datetime_rfc3339(s)
      if now.year == d.year
        return d.strftime('%l:%M %p').strip if now.yday == d.yday
      end
      d.strftime('%b %d %l:%M %p')
    end

    def datetime_rfc3339(s)
      DateTime.strptime(s, '%Y-%m-%dT%H:%M:%S%z')
      # Replace with d = DateTime.rfc3339(s)
    end

    def timed(&block)
      start = Time.now.to_f
      yield
      end_time = Time.now.to_f
      end_time - start
    end


    #
    # Git command helpers
    #

    def git(command, mode=:output)
      out = %x{ git #{command} 2>&1 }.strip
      say "git(#{$?.to_i}): #{out}" if debugging?
      return $?.to_i == 0 if mode == :succeeds
      return $? if mode == :exit_code
      say out and return $?.to_i == 0 if mode == :show
      raise "git #{command} did not succeed: #{$?.to_i}\n#{out}" if $?.to_i != 0
      out
    end

    def git_branch
      git('symbolic-ref HEAD').match(%r{\Arefs/heads/(.*)$})[1]
    end

    def from_git_root(&block)
      dir = git('rev-parse --show-cdup')
      if dir.empty?
        yield
      else
        Dir.chdir(dir, &block)
      end
    end

    def require_clean_git_dir!
      unless git('diff --quiet', :succeeds)
        raise "You have unsaved changes in your git repo #{`pwd`}.  Commit or revert your changes to run this command." 
      end
    end


    #
    # Global config
    #

    global_option '-c', '--config FILE', "Path of a different config file"
    def config
      raise "Operations requiring configuration must define a config accessor"
    end

    global_option '-l', '--rhlogin login', "Red Hat login (RedHat Network or OpenShift)"
    global_option '-p', '--password password', "Red Hat password"

    def openshift_server
      config.get_value('libra_server')
    end
    def openshift_url
      "https://#{openshift_server}"
    end


    #
    # Output helpers
    #

    def say(msg)
      super
      msg
    end
    def success(msg, *args)
      say color(msg, :green)
    end
    def warn(msg, *args)
      say color(msg, :yellow)
    end

    def color(s, color)
      $terminal.color(s, color)
    end

    def pluralize(count, s)
      count == 1 ? "#{count} #{s}" : "#{count} #{s}s"
    end

    def table(items, opts={}, &block)
      items = items.map &block if block_given?
      columns = []
      max = items.each do |item|
        item.each_with_index do |s, i|
          item[i] = s.to_s
          columns[i] = [columns[i] || 0, s.length].max if s.respond_to?(:length)
        end
      end
      align = opts[:align] || []
      join = opts[:join] || ' '
      items.map do |item|
        item.each_with_index.map{ |s,i| s.send((align[i] == :right ? :rjust : :ljust), columns[i], ' ') }.join(join).strip
      end
    end

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
    @@section_bottom_last = 0
    def section(params={}, &block)
      top = params[:top]
      top = 0 if top.nil?
      bottom = params[:bottom]
      bottom = 0 if bottom.nil?

      # add more newlines if top is greater than the last section's bottom margin
      top_margin = @@section_bottom_last

      # negitive previous bottoms indicate that an untracked newline was
      # printed and so we do our best to negate it since we can't remove it
      if top_margin < 0
        top += top_margin
        top_margin = 0
      end

      until top_margin >= top
        say "\n"
        top_margin += 1
      end

      block.call

      bottom_margin = 0
      until bottom_margin >= bottom
        say "\n"
        bottom_margin += 1
      end

      @@section_bottom_last = bottom
    end

    ##
    # paragraph
    #
    # highline helper which creates a section with margins of 1, 1
    #
    def paragraph(&block)
      section(:top => 1, :bottom => 1, &block)
    end

    # Platform helpers
    def jruby? ; RUBY_PLATFORM =~ /java/i end
    def windows? ; RUBY_PLATFORM =~ /win(32|dows|ce)|djgpp|(ms|cyg|bcc)win|mingw32/i end
    def unix? ; !jruby? && !windows? end

  end
end
