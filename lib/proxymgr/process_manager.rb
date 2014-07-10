module ProxyMgr
  class ProcessManager
    require 'timeout'

    include Callbacks

    attr_reader :exit_code, :pid

    def initialize(cmd, args = [], opts = {})
      @cmd        = cmd
      @args       = args
      @pid        = nil
      @exit_code  = nil

      @timeout    = opts[:timeout] || 10
      @setsid     = opts[:setsid] || true

      @io_handler = nil

      callbacks :on_stdout, :on_stderr
    end

    def start
      stdout_read, stdout_write = IO.pipe
      stderr_read, stderr_write = IO.pipe

      @pid = Process.fork do
        $stdout.reopen stdout_write
        $stderr.reopen stderr_write
        [stderr_read, stdout_read].each(&:close)
        begin
          Process.setsid if @setsid
        rescue Errno::EPERM
        end
        Process.exec *([@cmd] + @args)
      end
      @running = true

      [stdout_write, stderr_write].each(&:close)

      @thread = Thread.new do
        stop = false
        fdset = [stdout_read, stderr_read]
        until stop
          r = IO.select(fdset, [], fdset).first
          out = {}
          r.each do |pipe|
            stream = pipe == stdout_read ? :stdout : :stderr
            buf = out[stream] ||= ''
            begin
              loop { buf << pipe.read_nonblock(4096) }
            rescue Errno::EWOULDBLOCK
            rescue EOFError
              stop = true
            end
          end
          out.each do |stream, buf|
            buf.split(/\n/).each { |line| call("on_#{stream}".to_sym, line) }
          end
        end
        fdset.each(&:close)
      end
      @thread.abort_on_exception = true

      @pid
    end

    def running?
      if @pid
        wait(true)
        @running
      end
    end

    def stop
      Process.kill('TERM', @pid)
      begin
        Timeout.timeout(@timeout) { wait }
      rescue Timeout::Error
        Process.kill('KILL', @pid)
      end
      @thread.join if @thread
    end

    def wait(nohang = false)
      flags = nohang ? Process::WNOHANG : 0
      begin
        pid, result = Process.waitpid2(@pid, flags)
        if nohang and pid.nil? and result.nil?
          return
        end
        @exit_code = result.exitstatus || result.termsig
      rescue Errno::ECHILD
      end
      @running = false
    end
  end
end
