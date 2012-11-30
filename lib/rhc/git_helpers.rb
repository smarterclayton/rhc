require 'open4'
require 'rhc/wizard'

module RHC
  module GitHelpers
    def check_sshkeys!
      wizard = RHC::SSHWizard.new(rest_client)
      wizard.run
    end

    def git_clone_application(app)
      debug "Checking SSH keys through the wizard"
      check_sshkeys! unless options.noprompt

      repo_dir = options.repo || app.name

      debug "Pulling new repo down"
      git_clone_repo(app.git_url, repo_dir)

      debug "Configuring git repo"
      Dir.chdir(repo_dir) do |dir|
        git_config_set "rhc.app-uuid", app.uuid
      end

      true
    end

    def configure_git(rest_app)
    end

    # :nocov: These all call external binaries so test them in cucumber
    def git_config_get(key)
      config_get_cmd = "git config --get #{key}"
      debug "Running #{config_get_cmd}"
      uuid = %x[#{config_get_cmd}].strip
      debug "UUID = '#{uuid}'"
      uuid = nil if $?.exitstatus != 0 or uuid.empty?

      uuid
    end

    def git_config_set(key, value)
      unset_cmd = "git config --unset-all #{key}"
      config_cmd = "git config --add #{key} #{value}"
      debug "Adding #{key} = #{value} to git config"
      commands = [unset_cmd, config_cmd]
      commands.each do |cmd|
        debug "Running #{cmd} 2>&1"
        output = %x[#{cmd} 2>&1]
        raise RHC::GitException, "Error while adding config values to git - #{output}" unless output.empty?
      end  
    end

    def git_clone_repo(git_url, repo_dir)
      # quote the repo to avoid input injection risk
      repo_dir = (repo_dir ? " \"#{repo_dir}\"" : "")
      clone_cmd = "git clone #{git_url}#{repo_dir}"
      debug "Running #{clone_cmd}"

      err = nil
      if RHC::Helpers.windows?
        # windows does not support Open4 so redirect stderr to stdin
        # and print the whole output which is not as clean
        output = %x[#{clone_cmd} 2>&1]
        if $?.exitstatus != 0
          err = output + " - Check to make sure you have correctly installed git and it is added to your path."
        else
          say output
        end
      else
        paragraph do
          Open4.popen4(clone_cmd) do |pid, stdin, stdout, stderr|
            stdin.close
            say stdout.read
            err = stderr.read
          end
          say "done"
        end
      end

      raise RHC::GitException, "Error in git clone - #{err}" if $?.exitstatus != 0
    end
    # :nocov:
  end
end
