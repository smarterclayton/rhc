require 'rhc/commands/base'

class HighLine
  private
    def get_single_character(is_stty)
      if JRUBY
        @java_console.readVirtualKey
      elsif is_stty
        @input.getbyte
      else
        get_character(@input)
      end
    end
end

module RHC::Commands
  class Fast < Base

    summary ""
    description ""
    def run
      stty_raw do
        require_listen!
        require_clean_git_dir!

        from_git_root do
          say "Watching for changes in #{Dir.pwd}"

          establish_branch

          begin
            if options.push
              say "Pushing the new branch to the server... "
              git "push origin '#{@branch}'"
              say "DONE"
            end

            count = 1
            callback = Proc.new do |modified, added, removed|
              git "rm #{removed.join(' ')}" unless removed.empty?
              git "commit -a -m 'Change ##{count}'"

              if options.push
                say "  Pushing ##{count} (#{modified.length} changed, #{added.length} added, #{removed.length} removed)... "
                git "push origin '#{@branch}'"
                say "DONE"
              else
                say "  Commit ##{count} (#{modified.length} changed, #{added.length} added, #{removed.length} removed)"
              end

              count += 1
            end

            @listener = Listen.to(Dir.pwd).change(&callback)
            @listener.start(false)

            @continue = true
            while @continue
              $terminal.choose do |m|
                m.character = true
                m.layout = "> Take action by entering the specified key [<%= list( @menu.to_ary.map{ |s| \"(\#{s[0,1]})\#{s[1..-1]}\" }, :inline, '/' ) %>]\n"
                m.echo = false
                m.index = :none
                m.choice(:merge) { merge_and_quit }
                m.choice(:quit) { quit }
              end
            end
          rescue Interrupt
            say "  Cancelled applying changes"
          ensure
            cleanup
          end
        end
      end
      0
    end

    protected
      def establish_branch
        @branch = "development/#{Time.now.to_i}"
        @source_branch = git_branch
        say "Your changes will be in the branch #{@branch}, based on #{@source_branch}"
        git "checkout -b '#{@branch}'"
        [@branch, @source_branch]
      end

      def merge_and_quit
        @listener.stop
        say "Merging #{@branch} to #{@source_branch} and exit"
        git "checkout -f '#{@source_branch}'", :show
        git "merge '#{@branch}'", :show
        @continue = false
      end

      def quit
        @listener.stop
        say "Leaving changes in your branch #{@branch} and exit"
        @continue = false
      end

      def cleanup
        git "checkout -f '#{@source_branch}'"
        if git "diff --quiet '#{@branch}'..'#{@source_branch}'", :succeeds
          git "branch -d '#{@branch}'", :show
        end
      end

    private
      def require_listen!
        require 'listen'
      rescue LoadError
        raise <<-MESSAGE
You must install the gem 'listen' before you can use this command.

  sudo gem install listen
        MESSAGE
      end

      def stty_raw(&block)
        if HighLine::SystemExtensions::CHARACTER_MODE == 'stty'
          begin
            mode = `stty -g`
            system 'stty -echo -icanon isig'
            yield
          ensure
            system "stty #{mode}"
          end
        else
          yield
        end
      end
  end
end
