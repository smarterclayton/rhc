require 'commander'

module RHC
  module Commands
    def self.load
      Dir[File.join(File.dirname(__FILE__), "commands", "*.rb")].each do |file|
        require file
      end
      self
    end
    def self.add(opts)
      commands[opts[:name]] = opts
    end
    def self.global_option(*args, &block)
      global_options << [args, block]
    end
    def self.validate_command(c, args, options, args_metadata)
      # check to see if an arg's option was set
      raise ArgumentError.new("Invalid arguments") if args.length > args_metadata.length
      args_metadata.each_with_index do |arg_meta, i|
        switch = arg_meta[:switches]
        value = options.__hash__[arg_meta[:name]]
        unless value.nil?
          raise ArgumentError.new("#{arg_meta[:name]} specified twice on the command line and as a #{switch[0]} switch") unless args.length == i
          # add the option as an argument
          args << value
        end
      end
    end

    def self.global_config_setup(options)
      RHC::Config.set_opts_config(options.config) if options.config
      RHC::Config.password = options.password if options.password
      RHC::Config.opts_login = options.rhlogin if options.rhlogin
      RHC::Config.noprompt(options.noprompt) if options.noprompt
      RHC::Config
    end

    def self.needs_configuration!(cmd, config)
      # check to see if we need to run wizard
      if not cmd.class.suppress_wizard?
        w = RHC::Wizard.new config
        return w.run if w.needs_configuration?
      end
      false
    end

    def self.to_commander(instance=Commander::Runner.instance)
      global_options.each do |args, block|
        opts = (args.pop if Hash === args.last) || {}
        option = instance.global_option(*args, &block).last
        option.merge!(opts)
      end
      commands.each_pair do |name, opts|
        instance.command name do |c|
          c.description = opts[:description]
          c.summary = opts[:summary]
          c.syntax = opts[:syntax]

          (opts[:options]||[]).each { |o| c.option *o }

          args_metadata = opts[:args] || []
          args_metadata.each do |arg_meta|
            arg_switches = arg_meta[:switches]
            arg_switches << arg_meta[:description]
            c.option *arg_switches unless arg_switches.nil?
          end

          c.when_called do |args, options|
            validate_command c, args, options, args_metadata
            config = global_config_setup options
            cmd = opts[:class].new args, options, config
            needs_configuration! cmd, config
            cmd.send opts[:method], *args
          end

          unless opts[:aliases].nil?
            opts[:aliases].each do |a|
              alias_components = name.split(" ")
              alias_components[-1] = a
              instance.alias_command  "#{alias_components.join(' ')}", :"#{name}"
            end
          end
        end
      end
      self
    end

    protected
      def self.commands
        @commands ||= {}
      end
      def self.global_options
        @options ||= []
      end
  end
end
