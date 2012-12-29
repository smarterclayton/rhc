require 'rhc/rest/base'

module RHC
  module Rest
    class User < Base
      define_attr :login

      def add_key(name, content, type)
        debug "Add key #{name} of type #{type} for user #{login}"
        rest_method "ADD_KEY", :name => name, :type => type, :content => content
      end

      def keys
        debug "Getting all keys for user #{login}"
        rest_method "LIST_KEYS"
      end

      #Find Key by name
      def find_key(name)
        keys.detect { |key| key.name == name }
      end

      def add_authorization(scopes, expires_in=nil, note=nil)
        debug "Adding authorization for #{scopes} up to #{expires_in} with note #{note}"
        rest_method "ADD_AUTHORIZATION", :scopes => scopes, :note => note, :expires_in => expires_in
      end

      def list_authorizations
        rest_method "LIST_AUTHORIZATIONS"
      end

      def identities
        @identities ||= (attribute('identities') || [{:uid => login}]).map{ |i| Identity.new(i, self) }
      end
    end
  end
end
