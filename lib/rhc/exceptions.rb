module RHC
  class Exception < StandardError
    attr_reader :code
    def initialize(message=nil, code=1)
      super(message)
      @code = code
    end
  end

  class DomainNotFoundException < Exception
    def initialize(message="Domain not found")
      super message, 127
    end
  end

  class ApplicationNotFoundException < Exception
    def initialize(message="Application not found")
      super message, 101
    end
  end

  class CartridgeNotFoundException < Exception
    def initialize(message="Cartridge not found")
      super message, 154
    end
  end

  class MultipleCartridgesException < Exception
    def initialize(message="Multiple cartridge found")
      super message, 155
    end
  end

  class KeyNotFoundException < Exception
    def initialize(message="SSHKey not found")
      super message, 118
    end
  end

  class GitException < Exception
    def initialize(message="Git returned an error")
      super message, 216
    end
  end

  class GitPermissionDenied < GitException; end
  class GitDirectoryExists < GitException; end

  class DeprecatedError < RuntimeError; end
  
  class KeyFileNotExistentException < Exception
    def initialize(message="SSH Key file not found")
      super message, 128
    end
  end
  
  class KeyFileAccessDeniedException < Exception
    def initialize(message = "Insufficient acces to SSH Key file")
      super message, 128
    end
  end

  class KeyDataInvalidException < Exception
    def initialize(message = "SSH Key file contains invalid data")
      super message, 128
    end
  end

  class ScaledApplicationsNotSupportedException < Exception
    def initialize(message="Scaled applications not supported")
      super message, 128
    end
  end

  class PermissionDeniedException < Exception
    def initialize(message="Permission denied")
      super message, 129
    end
  end

  class NoPortsToForwardException < Exception
    def initialize(message="No available ports to forward")
      super message, 102
    end
  end

  class PortForwardFailedException < Exception
    def initialize(message="Port forward failed")
      super message, 1
    end
  end

  class SnapshotSaveException < Exception
    def initialize(message="Error trying to save snapshot")
      super message, 130
    end
  end

  class SnapshotRestoreException < Exception
    def initialize(message="Error trying to restore snapshot")
      super message, 130
    end
  end

  class MissingScalingValueException < Exception
    def initialize(message="Must provide either a min or max value for scaling")
      super message
    end
  end

  class CartridgeNotScalableException < Exception
    def initialize(message="Cartridge is not scalable")
      super message
    end
  end

  class ConnectionFailed < Exception
  end

  class SSHConnectionRefused < ConnectionFailed
    def initialize(host, user)
      super "The server #{host} refused a connection with user #{user}.  The application may be unavailable.", 1
    end
  end
end
