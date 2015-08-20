# ProxyMgr

ProxyMgr manages Haproxy configuration dynamically. It was built to facilitate communication between services
in cloud/dynamic environments where hosts providing a particular service may change frequently. DNS is typically
not an option in these environments as most clients will cache resolution of hostnames indefinitely. Other service
discovery solutions require integration in your applications, greatly increasing difficulty in adoption.

ProxyMgr attempts to solve these issues by implementing dynamic reconfiguration of Haproxy. It retrieves service configuration
data from Zookeeper and rewrites haproxy.cfg, as well as updating the state of the running process. It avoids reloading
the process wherever possible and takes care not to drop connections when a reload is needed.

## How it works

ProxyMgr discovers configuration for services (Haproxy frontends/backends) by querying a `service_config` instance. The retrieved
configuration is then used to set up a number of `watchers`, which are responsible for finding hosts that make up a service. Current
watcher implementations support retrieving service hosts from Zookeeper, DNS, flat files, etc.

## Installation

ProxyMgr is available from Rubygems:

```shell
$ gem install proxymgr
```

## Getting started

ProxyMgr has a configuration file which is used for configuring which service_config to use, as well as defaults for Haproxy. To configure
ProxyMgr to retrieve service configuration from Zookeeper you could put this in `proxymgr.yml`:

```yaml
---
haproxy:
  config_path: /etc/haproxy/haproxy.cfg
  socket_path: /var/run/haproxy/stats.sock

service_config:
  type: zookeeper
  servers: localhost:2181
  path: /service_config
```

ProxyMgr would then expect to find nodes in /service_config, where the name of the node would be the name of the listen section in Haproxy
and the data would contain a JSON blob configuring the watcher for that particular service. The blob could look like this if you would want the
watcher to retrieve hosts from Zookeeper:

```json
{"type": "zookeeper",
 "server": "localhost:2181",
 "path": "/services/testservice",
 "listen_options": ["mode http"],
 "server_options": ["check inter 2000"]}
```

ProxyMgr will now attempt to find nodes describing each server in /services/testservice. Each node should contain a blob looking like this:

```json
{"address": "1.2.3.4",
 "port": 8080}
```

## Configuration

ProxyMgr has a main configuration file, `proxymgr.yml`, which is used to configure which service_config to use as well as
certain Haproxy options. Each section is a hash of configuration values.

### `haproxy` section ###

This section accepts a number of configuration options:

* `global` should be an array of strings, where each element is a line which will appear in the global section of the Haproxy configuration.
* `socket_path` is the path to where the Haproxy stats socket is to be located. ProxyMgr will not be able to enable and disable backends without restarting if this is not supplied.
* `path` is the path to the Haproxy binary.

### `service_config` section ###

* `type` is the service_config type to use. "zookeeper" is currently the only available option.

Each service_config has its own configuration keys/values, which should also be put in this section.

#### `zookeeper` service_config ####

* `servers` is a list of servers (in format of host:port) separated by commas that should be used to find service configuration
* `path` is a path where service configuration nodes can be found.

## Haproxy management

ProxyMgr manages the Haproxy process directly; it does not rely on external process managers. This also enables ProxyMgr to provide seamless
reloads by opening listen sockets and passing them to Haproxy; as the listen socket remains open in ProxyMgr (the parent process), the kernel
will keep accepting connections during the window between when an old Haproxy process has stopped and a new process has not yet begun handling
requests.

ProxyMgr will attempt to avoid reloading Haproxy whenever necessary if stats_socket is configured. This is achieved by disabling and enabling
services through the stats socket when they become unavailable/available:

* If a server is removed, ProxyMgr will disable it through the Haproxy stats socket and write out a new configuration, but not reload the process.
* If a server which as previously been removed and disabled is added, ProxyMgr will re-enable it.
* If a new server is added, ProxyMgr will add it to the configuration and reload Haproxy.
* If a new backend is added, ProxyMgr will add it to the configuration and reload Haproxy.

## License

This project is licensed under the terms of the Apache License, version 2.0.
