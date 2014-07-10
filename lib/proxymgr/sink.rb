module ProxyMgr
  class Sink
    require 'absolute_time'
    require 'set'

    include Logging

    def initialize(haproxy, opts = {})
      @file            = opts[:haproxy_config_file] || '/tmp/haproxy.cfg'
      @default_timeout = opts[:default_timeout] || 2
      @max_timeout     = opts[:max_timeout] || 10
      @haproxy         = haproxy
      @timeout         = nil
      @thread          = nil
      @cv              = ConditionVariable.new
      @mutex           = Mutex.new
      @backends        = nil
      @haproxy.start
      start
    end

    def update_backends(backends)
      logger.debug 'Received new backends'
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
          if @timeout && t1 && AbsoluteTime.now - t1 >= @timeout && @backends
            @mutex.synchronize do
              changeset = find_existing_backends

              changeset.disable.each do |backend, hosts|
                hosts.each { |host| @haproxy.disable backend, host }
              end

              changeset.enable.each do |backend, hosts|
                hosts.each { |host| @haproxy.enable backend, host }
              end

              @haproxy.write_config(@backends)

              if changeset.restart_needed?
                logger.info 'Signaling haproxy to restart'
                @haproxy.restart
              end

              @timeout = nil
              @backends = nil
            end
          elsif t1
            set_timeout
            logger.debug "Waiting for #{@timeout}s or signal"
          end

          t1 = AbsoluteTime.now
          logger.debug 'Waiting to be signalled'
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

    def set_timeout
      @timeout = @timeout ? @timeout * @timeout : @default_timeout
      @timeout = @max_timeout if @timeout > @max_timeout
    end

    def find_existing_backends
      if @haproxy.socket?
        new_state = Hash[@backends.map do |name, watcher|
          [name, watcher.servers]
        end]
        old_state = @haproxy.servers.each_with_object({}) do |server, servers|
          backend = servers[server.backend] ||= { :disabled => [], :enabled => [] }
          if server.disabled?
            backend[:disabled] << server.name
          else
            backend[:enabled] << server.name
          end
        end
        restart_needed = new_state.keys.sort != old_state.keys.sort
        changeset = ChangeSet.new(restart_needed, {}, {})
        new_state.each_with_object(changeset) do |(backend, servers), cs|
          if old_state[backend]
            enabled    = old_state[backend][:enabled]
            to_disable = enabled - servers

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
        logger.debug 'No socket, not doing diffing'
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
