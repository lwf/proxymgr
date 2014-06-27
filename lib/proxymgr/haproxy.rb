module ProxyMgr
  class Haproxy
    require 'thread'
    require 'proxymgr/process_manager'

    include Logging

    def initialize(path, config_file, opts = {})
      @path             = path
      @config_file      = config_file

      @socket           = opts[:socket] ? Socket.new(opts[:socket]) : nil
      @respawn_interval = opts[:respawn_interval] || 5

      @process          = nil
      @thread           = nil
      @mutex            = Mutex.new
    end

    def start
      run

      @thread = Thread.new do
        loop do
          @mutex.synchronize do
            if @process and ret = @process.exit_code and ret > 0 and ret != 15
              logger.warn "haproxy exited with status code #{ret}. Respawning in #{@respawn_interval}s"
              sleep @respawn_interval
              run
            end
          end
          @process.wait
        end
      end
      @thread.abort_on_exception = true
    end

    def restart
      @mutex.synchronize { run(@process.pid) }
    end

    def stop
      @mutex.synchronize do
        @thread.kill
        @thread.join
        @process.stop
      end
    end

    def socket?
      @socket
    end

    def stats
      headers, *rest = @socket.write("show stat")
      headers = headers.gsub(/^# /, '').split(",")
      rest.pop
      rest.map { |d| Hash[headers.zip(d.split(","))] }
    end

    def down(backend, host, opts = {:shutdown => false})
      @socket.write "disable server #{backend}/#{host}"

      if opts[:shutdown]
        @socket.write "shutdown sessions server #{backend}/#{host}"
      end
    end

    private

    def run(pid = nil)
      args = ['-f', @config_file]
      if pid
        args << '-sf'
        args << pid.to_s
      end

      @process = ProcessManager.new(@path, args)
      @process.start
    end

    class Socket
      require 'socket'

      def initialize(path)
        @path = path
      end

      def write(cmd)
        with do |socket|
          socket.puts(cmd + "\n")
          socket.readlines.map(&:chomp)
        end
      end

      private

      def with
        yield UNIXSocket.new(@path)
      end
    end
  end
end
