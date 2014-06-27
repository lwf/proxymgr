module ProxyMgr
  class ProcessManager
    require 'timeout'

    attr_reader :exit_code, :pid

    def initialize(cmd, args = [], opts = {})
      @cmd       = cmd
      @args      = args
      @pid       = nil
      @exit_code = nil

      @timeout   = opts[:timeout] || 10
      @setsid    = opts[:setsid] || true
    end

    def start
      @pid = Process.fork do
        begin
          Process.setsid if @setsid
        rescue Errno::EPERM
        end
        Process.exec *([@cmd] + @args)
      end
    end

    def stop
      Process.kill("TERM", @pid)
      begin
        Timeout.timeout(@timeout) { wait }
      rescue Timeout::Error
        Process.kill("KILL", @pid)
      end
    end

    def wait
      begin
        pid, result = Process.waitpid2 @pid
        @exit_code = result.exitstatus || result.termsig
      rescue Errno::ECHILD
      end
    end
  end
end
