require 'rhc/commands/base'

module RHC::Commands
  class Apps < Base
    summary "List all your applications"
    description "Display the list of applications that you own. Includes information about each application."
    def run
      domains = rest_client.domains

      say "In order to deploy applications, you must create a domain with 'rhc setup' or 'rhc domain create'." and return 1 if domains.empty?

      applications = domains.map(&:applications).flatten.sort

      applications.each{ |a| display_app(a, a.cartridges) }.blank? and
        say "No applications. Use 'rhc app create'." and
        return 1

      0
    end
  end
end
