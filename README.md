# ProxyMgr

ProxyMgr manages Haproxy configuration dynamically.

Features include:
  * Manage configuration of Haproxy backends through dynamic sources (currently only Zookeeper, more to come).
  * Watchers for updating backend servers based on DNS changes, Zookeeper node changes, etc.
  * Process management; no need for external tools like Upstart/runit/etc.
  * Seamless restarts by way of fd-passing.

## Installation

Make sure you have a reasonably recent Ruby (2.0+). Then install Bundler:

```shell
$ gem install bundler
```

Install dependencies:

```shell
$ bundle
```
