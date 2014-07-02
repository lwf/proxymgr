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

      [stdout_write, stderr_write].each(&:close)

      @thread = Thread.new do
        stop = false
        until stop
          fdset = [stdout_read, stderr_read]
          r, w, e = IO.select(fdset, [], fdset)
          out = {}
          r.each do |pipe|
            stream = pipe == stdout_read ? :stdout : :stderr
            buf = out[stream] ||= ""
            begin
              loop { buf << pipe.read_nonblock(4096) }
            rescue Errno::EWOULDBLOCK, EOFError
            end
            stop = pipe.eof?
          end
          out.each do |stream, buf|
            buf.split(/\n/).each { |line| call("on_#{stream}".to_sym, line) }
          end
        end
      end
      @thread.abort_on_exception = true

      @pid
    end

    def stop
      Process.kill("TERM", @pid)
      begin
        Timeout.timeout(@timeout) { wait }
      rescue Timeout::Error
        Process.kill("KILL", @pid)
      end
      if @thread
        @thread.kill
        @thread.join
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
