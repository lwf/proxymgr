module ProxyMgr
  class Sink
    require 'absolute_time'
    require 'zlib'

    def initialize
      @file            = '/tmp/haproxy.cfg'

      @timeout         = nil
      @default_timeout = 2
      @max_timeout     = 20

      @main_thread     = nil
      @main_cv         = ConditionVariable.new
      @main_mutex      = Mutex.new

      @haproxy_thread  = nil
      @haproxy_mutex   = Mutex.new
      @haproxy_cv      = ConditionVariable.new

      start_haproxy
      start_main
    end

    def write_backends(backends)
      content = backends.map do |name, watcher|
        next if watcher.servers.empty?
        port = (Zlib.crc32(name) % 65534) + 1
        <<EOF
listen #{name} 0.0.0.0:#{port}
  #{watcher.servers.map { |s| "server #{s} #{s}" }.join("\n  ")}
EOF
      end

      @haproxy_mutex.synchronize { write(content.join("\n")) }

      signal_haproxy
      signal_main
    end

    def shutdown
      @main_thread.kill
      @main_thread.join
      @haproxy_thread.kill
      @haproxy_thread.join
      @pid.stop
      @pid.wait
    end

    private

    def start_main
      @main_thread = Thread.new do
        t1 = nil
        loop do
          if @timeout and t1 and AbsoluteTime.now-t1 >= @timeout
            ProxyMgr.logger.info "Signaling haproxy to restart"
            restart_haproxy
            @timeout = nil
          else
            @timeout = @timeout ? @timeout * @timeout : @default_timeout

            if @timeout > @max_timeout
              @timeout = @max_timeout
            end
          end

          t1 = AbsoluteTime.now
          ProxyMgr.logger.debug "Waiting to be signalled"
          wait
        end
      end
      @main_thread.abort_on_exception = true
    end

    def signal_main
      @main_mutex.synchronize { @main_cv.signal }
    end

    def wait
      @main_mutex.synchronize { @main_cv.wait(@main_mutex, @timeout) }
    end

    def start_haproxy
      @haproxy_thread = Thread.new do
        @haproxy_mutex.synchronize { @haproxy_cv.wait(@haproxy_mutex) }
        run_haproxy

        loop do
          @haproxy_mutex.synchronize do
            if @pid and ret = @pid.exit_code and ret > 0 and ret != 15
              ProxyMgr.logger.warn "haproxy exited with status code #{ret}. Respawning in 5s"
              sleep 5
              run_haproxy
            end
          end
          @pid.wait
        end
      end
      @haproxy_thread.abort_on_exception = true
    end

    def run_haproxy(pid = nil)
      args = ['-f', @file]
      if pid
        args << '-sf'
        args << pid
      end

      @pid = ProcessManager.new('/tmp/haproxy', args)
      @pid.start
    end

    def signal_haproxy
      @haproxy_mutex.synchronize { @haproxy_cv.signal }
    end

    def restart_haproxy
      @haproxy_mutex.synchronize { run_haproxy @pid.pid.to_s }
    end

    def write(contents)
      f = nil
      begin
        f = File.open(@file, 'w')
        f.syswrite contents
      ensure
        f.close if f
      end
    end
  end
end
