module ProxyMgr
  class ProcessManager
    require 'timeout'

    include Logging

    attr_reader :exit_code, :pid

    def initialize(cmd, args = [], opts = {})
      @cmd       = cmd
      @args      = args
      @pid       = nil
      @exit_code = nil

      @io_handler = nil

      @timeout   = opts[:timeout] || 10
      @setsid    = opts[:setsid] || true
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
        running = true
        while running
          puts "top loop #{Thread.current.object_id}"
          fdset = [stdout_read, stderr_read]
          r, w, e = IO.select(fdset, [], fdset)
          r.each do |pipe|
            buf = ''
            begin
              loop { buf << pipe.read_nonblock(4096); p buf }
            rescue Errno::EWOULDBLOCK
            end
            buf.split(/\n/).each { |line| logger.info line }
            running = pipe.eof?
          end
        end
        puts "stopped #{Thread.current.object_id}"
      end
    end

    def stop
      p @pid
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
