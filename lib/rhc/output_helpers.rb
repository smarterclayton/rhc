module RHC
  module OutputHelpers
    # Issues collector collects a set of recoverable issues and steps to fix them
    # for output at the end of a complex command
    def add_issue(reason, commands_header, *commands)
      @issues ||= []
      issue = {:reason => reason,
               :commands_header => commands_header,
               :commands => commands}
      @issues << issue
    end

    def format_issues(indent)
      return nil unless issues?

      indentation = " " * indent
      reasons = ""
      steps = ""

      @issues.each_with_index do |issue, i|
        reasons << "#{indentation}#{i+1}. #{issue[:reason].strip}\n"
        steps << "#{indentation}#{i+1}. #{issue[:commands_header].strip}\n"
        issue[:commands].each { |cmd| steps << "#{indentation}  $ #{cmd}\n" }
      end

      [reasons, steps]
    end

    def issues?
      not @issues.nil?
    end

    #---------------------------
    # Application information
    #---------------------------
    def display_app(app, cartridges=nil)
      paragraph do
        header "%s @ %s (uuid: %s)" % [app.name, app.app_url, app.uuid]
        say table([:creation_time, :gear_profile, :git_url, :ssh_string, :aliases].map do |sym|
          v = app.send(sym)
          [' ', "#{table_heading(sym)}:", format_value(sym, v)] if v.present?
        end.compact).join("\n")
        paragraph do
          header "Cartridges"
          (cartridges || []).sort.each do |c|
            line = [c.name]
            line << "(#{c.display_name})" if c.display_name != c.name
            line << format_scale_info(c) if c.scalable?
            say line.join(' ')
            say "  #{c.connection_info}" if c.connection_info
          end.blank? and say "None"
        end
      end
    end

    def format_scale_info(cart)
      "Scaled x%d (minimum: %s, maximum: %s) on %s gears" % 
        [:current_scale, :scales_from, :scales_to, :gear_profile].map{ |s| format_value(s, cart.send(s)) }
    end

    def display_app_properties(app,*properties)
      say_table \
        "Application Info",
        get_properties(app,*properties),
        :delete => true
    end

    def display_included_carts(carts)
      properties = carts.map{ |c| [c.name, c.connection_info] }
      properties = "None" unless properties.present?

      say_table \
        "Cartridges",
        properties,
        :preserve_keys => true
    end

    def display_scaling_info(app,cart)
      # Save these values for easier reuse
      values = [:current_scale,:scales_from,:scales_to,:scales_with]
      # Get the scaling properties we care about
      properties = get_properties(cart,*values)
      # Format the string for applications
      properties = "Scaled x%d (minimum: %s, maximum: %s) with %s on %s gears" %
        [properties.values_at(*values), cart.gear_profile].flatten

      say_table \
        "Scaling Info",
        properties
    end

    #---------------------------
    # Cartridge information
    #---------------------------

    def display_cart(c, properties = nil)
      line = ["Cartridge", c.name]
      line << "(#{c.display_name})" if c.display_name.present?
      header line.join(' ') do
        say format_scale_info(c) if c.scalable?
        say "  Connection URL: #{c.connection_info}" if c.connection_info
      end
    end

    def display_cart_properties(cart,properties)
      # We need to actually access the cart because it's not a simple hash
      properties = get_properties(cart,*properties.keys) do |prop|
        cart.property(:cart_data,prop)["value"]
      end

      say_table \
        "Properties",
        properties
    end

    def display_cart_scaling_info(cart)
      say_table \
        "Scaling Info",
        get_properties(cart,:current_scale,:scales_from,:scales_to)
    end

    #---------------------------
    # Misc information
    #---------------------------

    def display_no_info(type)
      say_table \
        nil,
        ["This #{type} has no information to show"]
    end

    private
      def say_table(heading,values,opts = {})
        @table_displayed = true
        table = make_table(values,opts)

        # Go through all the table rows
        _proc = proc{
          table.each do |s|
            # Remove trailing = (like for cartridges list)
            indent s.gsub(/\s*=\s*$/,'')
          end
        }

        # Make sure we nest properly
        if heading
          header heading do
            _proc.call
          end
        else
          _proc.call
        end
      end

      # This uses the array of properties to retrieve them from an object
      def get_properties(object,*properties)
        Hash[properties.map do |prop|
          # Either send the property to the object or yield it
          value = block_given? ? yield(prop) : object.send(prop)
          # Some values (like date) need some special handling
          value = format_value(prop,value)

          [prop,value]
        end]
      end

      # Format some special values
      def format_value(prop,value)
        case prop
        when :creation_time
          date(value)
        when :scales_to, :supported_scales_to
          (value == -1 ? "available gears" : value)
        when :aliases
          value.join ' '
        else
          value
        end
      end

      # Make the rows for the table
      #   If we pass a hash, it will manipulate it into a nice table
      #   Arrays and single vars will just be passed back as arrays
      def make_table(values,opts = {})
        case values
        when Hash
          # Loop through the values in case we need to fix them
          _values = values.inject({}) do |h,(k,v)|
            # Format the keys based on the table_heading function
            #  If we pass :preserve_keys, we leave them alone (like for cart names)
            key = opts[:preserve_keys] ? k : table_heading(k)

            # Replace empty or nil values with spaces
            #  If we pass :delete, we assume those are not needed
            if v.blank?
              h[key] = "" unless opts[:delete]
            else
              h[key] = v.to_s
            end
            h
          end
          # Join the values into rows
          table _values, :join => " = "
          # Create a simple array
        when Array
          values
        else
          [values]
        end
      end
  end
end
