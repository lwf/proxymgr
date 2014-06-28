module ProxyMgr
  class Sink
    require 'absolute_time'
    require 'zlib'
    require 'tempfile'
    require 'pathname'
    require 'set'

    include Logging

    def initialize(haproxy, opts = {})
      @file            = opts[:haproxy_config_file] || '/tmp/haproxy.cfg'
      @default_timeout = opts[:default_timeout] || 2
      @max_timeout     = opts[:max_timeout] || 20
      @haproxy         = haproxy

      @timeout         = nil
      @thread          = nil
      @cv              = ConditionVariable.new
      @mutex           = Mutex.new

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
              changeset = find_existing_backends

              changeset.disable.each do |backend, hosts| 
                hosts.each { |host| @haproxy.disable backend, host }
              end

              changeset.enable.each do |backend, hosts|
                hosts.each { |host| @haproxy.enable backend, host }
              end

              write_config

              if changeset.restart_needed?
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

    def find_existing_backends
      if @haproxy.socket?
        new_state = Hash[@backends.map { |name, watcher| [name, watcher.servers] }]
        old_state = @haproxy.servers.inject({}) do |servers, server|
          backend = servers[server.backend] ||= {:disabled => [], :enabled => []}
          if server.disabled?
            backend[:disabled] << server.name
          else
            backend[:enabled] << server.name
          end
          servers
        end
        restart_needed = new_state.keys.sort != old_state.keys.sort
        changeset = ChangeSet.new(restart_needed, {}, {})
        new_state.inject(changeset) do |cs, (backend, servers)|
          if old_state[backend]
            enabled    = Set.new(old_state[backend][:enabled])
            to_disable = enabled.difference(servers)

            disabled  = old_state[backend][:disabled]
            to_enable = (disabled & servers)
            if ((enabled - to_disable) + to_enable).sort != servers.sort
              cs.restart_needed = true
            end

            cs.disable[backend] = to_disable
            cs.enable[backend]  = to_enable
          end
          cs
        end
      else
        ChangeSet.new(true, {}, {})
      end
    end

    class ChangeSet < Struct.new(:restart_needed, :disable, :enable)
      def restart_needed?
        restart_needed
      end
    end
  end
end
