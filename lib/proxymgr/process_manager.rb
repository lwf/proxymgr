module ProxyMgr
  class ProcessManager
    require 'timeout'
    require 'proxymgr/process_manager/signal_handler'

    include Callbacks

    attr_reader :exit_code, :pid

    def initialize(cmd, args = [], opts = {})
      @cmd        = cmd
      @args       = args
      @pid        = nil
      @exit_code  = nil

      @timeout    = opts[:timeout] || 10
      @setsid     = opts[:setsid] || true
      @fds        = opts[:fds] || []

      @io_handler = nil

      callbacks :on_stdout, :on_stderr, :on_stop
    end

    def start
      stdout_read, stdout_write = IO.pipe
      stderr_read, stderr_write = IO.pipe
      sync_pipe                 = IO.pipe

      @pid = Process.fork do
        $stdout.reopen stdout_write
        $stderr.reopen stderr_write
        [stderr_read, stdout_read].each(&:close)
        begin
          Process.setsid if @setsid
        rescue Errno::EPERM
        end
        sync_pipe[0].read(1)
        3.upto(Platform.max_fd).each do |fd|
          begin
            IO.for_fd(fd).close unless @fds.include? fd
          rescue ArgumentError, Errno::EBADF
          end
        end
        Process.exec(*([@cmd] + @args), :close_others => false)
      end
      self.class.register(@pid) { |status| call(:on_stop, status) }
      sync_pipe[1].write(1)
      ([stdout_write, stderr_write] + sync_pipe).each(&:close)

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

    def stop
      Process.kill('TERM', @pid)
      begin
        Timeout.timeout(@timeout) { wait }
      rescue Timeout::Error
        Process.kill('KILL', @pid)
      end
      @thread.join if @thread
    end

    def wait
      begin
        _pid, result = Process.waitpid2(@pid)
        @exit_code = result.exitstatus || result.termsig
      rescue Errno::ECHILD
      end
    end

    def self.register(pid, &blk)
      @handler ||= SignalHandler.new
      @handler.register(pid, &blk)
    end
  end
end
