module RHC::Auth
  class Basic
    attr_reader :cookie

    def initialize(*args)
      if args[0].is_a?(String) or args.length > 1
        @username, @password = args
      else
        @options = args[0] || Commander::Command::Options.new
        @username = options.rhlogin
        @password = options.password
        @token = options.token
      end
    end

    def to_request(request)
      (request[:cookies] ||= {})[:rh_sso] = cookie if cookie
      if token
        (request[:headers] ||= {})[:authorization] = "Bearer #{token}"
      else
        request[:user] ||= username || (request[:lazy_auth] != true && ask_username)
        request[:password] ||= password || (username? && request[:lazy_auth] != true && ask_password)
      end
      request
    end

    def retry_auth?(response)
      if response.code == 401
        @cookie = nil
        if token
          error "Your access token has expired.  Run 'rhc setup' again."
          false
        else
          ask_username unless username?
          error "Username or password is not correct" if password
          ask_password
        end
        true
      else
        @cookie ||= response.cookies['rh_sso']
        false
      end
    end

    protected
      include RHC::Helpers
      attr_reader :options, :username, :password, :token

      def ask_username
        @username = ask("Login to #{openshift_server}: ")
      end
      def ask_password
        @password = ask("Password: ") { |q| q.echo = '*' }
      end

      def username?
        username.present?
      end
  end
end
