module ProxyMgr
  class Sink
    require 'absolute_time'
    require 'zlib'
    require 'tempfile'
    require 'pathname'
    require 'set'

    include Logging

    def initialize(opts = {})
      @file            = opts[:haproxy_config_file] || '/tmp/haproxy.cfg'
      @default_timeout = opts[:default_timeout] || 2
      @max_timeout     = opts[:max_timeout] || 20

      @timeout         = nil
      @thread          = nil
      @cv              = ConditionVariable.new
      @mutex           = Mutex.new

      @haproxy         = Haproxy.new('/tmp/haproxy', @file, :socket => "/tmp/stats.sock")

      @backends        = nil

      @haproxy.start
      start
    end

    def write_backends(backends)
      logger.debug "Received new backends"
      @mutex.synchronize do 
        @backends ||= {}
        backends.each do |name, watcher|
          next if watcher.servers.empty?
          @backends[name] = watcher
        end
      end
      signal
    end

    def shutdown
      @thread.kill
      @thread.join
      @haproxy.stop
    end

    private

    def start
      @thread = Thread.new do
        t1 = nil
        loop do
          if @timeout and t1 and AbsoluteTime.now-t1 >= @timeout and @backends
            @mutex.synchronize do
              up, down = changed_backends

              logger.debug "Hosts up: #{up.values.flatten.join(", ")}, hosts down: #{down.values.flatten.join(", ")}"
              down.each do |backend, hosts| 
                hosts.each { |host| @haproxy.down backend, host }
              end

              write_config

              unless up.values.flatten.empty?
                logger.info "Signaling haproxy to restart"
                @haproxy.restart
              end

              @timeout = nil
              @backends = nil
            end
          elsif t1
            @timeout = @timeout ? @timeout * @timeout : @default_timeout

            if @timeout > @max_timeout
              @timeout = @max_timeout
            end

            logger.debug "Waiting for #{@timeout.to_s}s or signal"
          end

          t1 = AbsoluteTime.now
          logger.debug "Waiting to be signalled"
          wait
        end
      end
      @thread.abort_on_exception = true
    end

    def signal
      @mutex.synchronize { @cv.signal }
    end

    def wait
      @mutex.synchronize { @cv.wait(@mutex, @timeout) }
    end

    def write_config
      f = nil
      begin
        f = Tempfile.new('haproxy')
        content = "global\n\tstats socket /tmp/stats.sock mode 666 level admin\n"
        content << @backends.map do |name, watcher|
          "listen #{name} 0.0.0.0:#{Zlib.crc32(name) % 65535}\n  " +
          watcher.servers.map { |host| "  server #{host} #{host}" }.join("\n")
        end.join("\n")
        f.write content
        f.close
        Pathname.new(f.path).rename(@file)
      rescue Exception => e
        logger.warn "Unable to write to #{@file}: #{e}"
        File.unlink f.path if f
      end
    end

    def changed_backends
      updated_state = Hash[@backends.map do |name, watcher|
        [name, watcher.servers]
      end]
      up, down = updated_state, {}
      if @haproxy.socket?
        proxy_state = {}
        @haproxy.stats.each do |stat|
          if ["FRONTEND", "BACKEND"].include? stat["svname"] or stat["status"] == "MAINT"
            next
          end
          backend = stat["pxname"]
          server  = stat["svname"]
          proxy_state[backend] ||= Set.new
          proxy_state[backend] << server
        end
        proxy_state.each do |name, hosts|
          down[name] = hosts.difference(updated_state[name]).to_a
        end
        updated_state.each do |name, hosts|
          up[name] = hosts.to_set.difference(proxy_state[name]).to_a
        end
      end
      [up, down]
    end
  end
end
