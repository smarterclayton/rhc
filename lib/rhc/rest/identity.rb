require 'rhc/rest/base'

module RHC
  module Rest
    class Identity < Base
      define_attr :provider, :uid, :created_at
      alias_method :login, :uid
    end
  end
end
