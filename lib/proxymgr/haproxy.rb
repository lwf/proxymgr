module ProxyMgr
  class Haproxy
    require 'thread'
    require 'zlib'
    require 'tempfile'
    require 'pathname'
    require 'erb'
    require 'proxymgr/process_manager'

    include Logging

    def initialize(path, config_file, opts = {})
      @path             = path
      @config_file      = config_file

      @socket_path      = opts[:socket]
      @respawn_interval = opts[:respawn_interval] || 5
      @global_config    = opts[:global]
      @defaults_config  = opts[:defaults]

      @socket           = @socket_path ? Socket.new(@socket_path) : nil
      @config_template  = ERB.new(File.read(File.join(ProxyMgr.template_dir, 'haproxy.cfg.erb')))

      @process          = nil
      @thread           = nil
      @mutex            = Mutex.new
    end

    def version
      `#{@path} -v`[/version ([\d\.]+)/, 1].to_f
    end

    def start
      run

      @thread = Thread.new do
        loop do
          @mutex.synchronize do
            if @process.running? && ret = @process.exit_code && ret > 0 && ret != 15
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

    def write_config(backends)
      f = nil
      begin
        f = Tempfile.new('haproxy')
        f.write @config_template.result(binding)
        f.close
        Pathname.new(f.path).rename(@config_file)
      rescue Exception => e
        logger.warn "Unable to write to #{@config_file}: #{e}"
        File.unlink f.path if f
      end
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
      @socket and @process.running?
    end

    def servers
      stats.each_with_object([]) do |stat, acc|
        next if %w(FRONTEND BACKEND).include? stat['svname']
        acc << Server.new(self, stat)
      end
    end

    def stats
      headers, *rest = @socket.write('show stat')
      headers = headers.gsub(/^# /, '').split(',')
      rest.pop
      rest.map { |d| Hash[headers.zip(d.split(','))] }
    end

    def enable(backend, host)
      @socket.write "enable server #{backend}/#{host}"
    end

    def disable(backend, host)
      @socket.write "disable server #{backend}/#{host}"
    end

    def shutdown(backend, host)
      @socket.write "shutdown sessions server #{backend}/#{host}"
    end

    private

    def run(pid = nil)
      args = ['-f', @config_file, '-db']
      if pid
        args << '-sf'
        args << pid.to_s
      end

      @process = ProcessManager.new(@path, args)
      [:on_stdout, :on_stderr].each do |cb|
        @process.send(cb, &method(:parse_haproxy_log))
      end
      @process.start
    end

    def parse_haproxy_log(line)
      matches = line.scan(/^\[(.*)\] (.*)/)[0]
      if matches
        haproxy_level, msg = matches
        level = haproxy_level == 'WARNING' ? :warn : :info
        logger.send(level, msg)
      else
        logger.info(line)
      end
    end

    class Socket
      require 'socket'

      attr_reader :path

      def initialize(path)
        @path = path
      end

      def write(cmd)
        with do |socket|
          socket.puts(cmd + '\n')
          socket.readlines.map(&:chomp)
        end
      end

      private

      def with
        yield UNIXSocket.new(@path)
      end
    end

    class Server
      attr_reader :stats

      def initialize(haproxy, stats)
        @haproxy = haproxy
        @stats   = stats
      end

      def backend
        @stats['pxname']
      end

      def name
        @stats['svname']
      end

      def disable
        @haproxy.disable backend, name
      end

      def shutdown
        @haproxy.shutdown backend, name
      end

      def disabled?
        @stats['status'] == 'MAINT'
      end
    end
  end
end
