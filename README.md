# Etcd2 Initial Cluster Discovery for new Clusters in CoreOS 835.9.0

## The Problem

When etcd first comes up, using cluster discovery, it seems to get confused about who 
is a member and who is a proxy, and then gets stuck, refusing ever to change its mind.

This happens in roughly 8 out of 10 cluster bringups. (The other 2 work fine.)

## Versions
This issue has been found on
* CoreOS Stable: CoreOS 835.9.0; etcd 2.2.0.
* CoreOS Beta: CoreOS 877.1.0; etcd 2.2.2.
* CoreOS Alpha: CoreOS 884.0.0; etcd 2.2.2.

## cloudinit

The initial cloudinit setup files for these hosts looks like the following:

```
#cloud-config
coreos:
  etcd2:
    # generate a new token for each unique cluster from https://discovery.etcd.io/new
    discovery: https://discovery.etcd.io/b4e8d34f98130cd02a85a507fd99fd2c
    # multi-region and multi-cloud deployments need to use $public_ipv4
    advertise-client-urls: http://$private_ipv4:2379
    initial-advertise-peer-urls: http://$private_ipv4:2380
    listen-client-urls: http://0.0.0.0:2379,http://0.0.0.0:4001
    listen-peer-urls: http://$private_ipv4:2380,http://$private_ipv4:7001
  units:
    - name: etcd2.service
      command: start
    - name: fleet.service
      command: start
```

That discovery token is regenerated for each new cluster.

## Logs

When a host comes up in failure mode, it's first `etcd2.service` log looks like:

```
Dec 07 23:47:00 trouble-etcd-e systemd[1]: Starting etcd2...
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: recognized and used environment variable ETCD_ADVERTISE_CLIENT_URLS=http://10.240.0.5:2379
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: recognized and used environment variable ETCD_DATA_DIR=/var/lib/etcd2
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: recognized and used environment variable ETCD_DISCOVERY=https://discovery.etcd.io/b86bdd008160b8d7bd352262ce2e0c33
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: recognized and used environment variable ETCD_INITIAL_ADVERTISE_PEER_URLS=http://10.240.0.5:2380
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: recognized and used environment variable ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379,http://0.0.0.0:4001
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: recognized and used environment variable ETCD_LISTEN_PEER_URLS=http://10.240.0.5:2380,http://10.240.0.5:7001
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: recognized and used environment variable ETCD_NAME=52f206ffb747382c49bfde7c3d21b5d7
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: etcd Version: 2.2.0
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: Git SHA: e4561dd
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: Go Version: go1.4.2
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: Go OS/Arch: linux/amd64
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: setting maximum number of CPUs to 1, total number of available CPUs is 1
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: listening for peers on http://10.240.0.5:2380
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: listening for peers on http://10.240.0.5:7001
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: listening for client requests on http://0.0.0.0:2379
Dec 07 23:47:01 trouble-etcd-e etcd2[757]: listening for client requests on http://0.0.0.0:4001
Dec 07 23:47:06 trouble-etcd-e etcd2[757]: stopping listening for client requests on http://0.0.0.0:4001
Dec 07 23:47:06 trouble-etcd-e systemd[1]: etcd2.service: Main process exited, code=exited, status=1/FAILURE
Dec 07 23:47:06 trouble-etcd-e systemd[1]: Failed to start etcd2.
Dec 07 23:47:06 trouble-etcd-e systemd[1]: etcd2.service: Unit entered failed state.
Dec 07 23:47:06 trouble-etcd-e systemd[1]: etcd2.service: Failed with result 'exit-code'.
Dec 07 23:47:16 trouble-etcd-e systemd[1]: etcd2.service: Service hold-off time over, scheduling restart.
Dec 07 23:47:16 trouble-etcd-e systemd[1]: Stopped etcd2.
```

Subsequent restarts are nearly the same:

```
Dec 07 23:47:16 trouble-etcd-e systemd[1]: Starting etcd2...
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: recognized and used environment variable ETCD_ADVERTISE_CLIENT_URLS=http://10.240.0.5:2379
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: recognized and used environment variable ETCD_DATA_DIR=/var/lib/etcd2
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: recognized and used environment variable ETCD_DISCOVERY=https://discovery.etcd.io/b86bdd008160b8d7bd352262ce2e0c33
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: recognized and used environment variable ETCD_INITIAL_ADVERTISE_PEER_URLS=http://10.240.0.5:2380
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: recognized and used environment variable ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379,http://0.0.0.0:4001
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: recognized and used environment variable ETCD_LISTEN_PEER_URLS=http://10.240.0.5:2380,http://10.240.0.5:7001
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: recognized and used environment variable ETCD_NAME=52f206ffb747382c49bfde7c3d21b5d7
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: etcd Version: 2.2.0
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: Git SHA: e4561dd
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: Go Version: go1.4.2
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: Go OS/Arch: linux/amd64
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: setting maximum number of CPUs to 1, total number of available CPUs is 1
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: the server is already initialized as member before, starting as etcd member...
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: listening for peers on http://10.240.0.5:2380
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: listening for peers on http://10.240.0.5:7001
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: listening for client requests on http://0.0.0.0:2379
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: listening for client requests on http://0.0.0.0:4001
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: stopping listening for client requests on http://0.0.0.0:4001
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: stopping listening for client requests on http://0.0.0.0:2379
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: stopping listening for peers on http://10.240.0.5:7001
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: stopping listening for peers on http://10.240.0.5:2380
Dec 07 23:47:16 trouble-etcd-e etcd2[956]: discovery: cluster is full
Dec 07 23:47:16 trouble-etcd-e systemd[1]: etcd2.service: Main process exited, code=exited, status=1/FAILURE
Dec 07 23:47:16 trouble-etcd-e systemd[1]: Failed to start etcd2.
Dec 07 23:47:16 trouble-etcd-e systemd[1]: etcd2.service: Unit entered failed state.
Dec 07 23:47:16 trouble-etcd-e systemd[1]: etcd2.service: Failed with result 'exit-code'.
Dec 07 23:47:26 trouble-etcd-e systemd[1]: etcd2.service: Service hold-off time over, scheduling restart.
Dec 07 23:47:26 trouble-etcd-e systemd[1]: Stopped etcd2.
```

Though we have the noticible difference now of actually getting an error message: `discovery: cluster is full`.

## Workaround

So etcd2 is supposed to have automatic proxy fallback if more hosts than are requested try and join the cluster,
but this doesn't seem to be working. It seems that the service is convinced at this point that it must be configured
as a member, and not a proxy. The content of the `/var/lib/etcd2` directory at this stage is just an empty directory
called `member`.

Fixing the issue is as simple as removing the `member` directory. Then the automatically restarting etcd2 service will 
forget that it thinks it should be a member of the cluster and will fall back to being a proxy.

(One caveat, though: it generates both a `member` and a `proxy` directory during this fallback, and if you try to restart
the etcd2 service later, you'll get an error about being configured both as a member and as a proxy. Again: just
remove the `member` directory, and restarting the service will become possible.)

## The Scripts

The script `make_cluster.sh` here demonstrates this scenario and the associated workaround. `clean.sh` will clean up
afterwards. Both of these scripts assume that you have access to Google Compute Engine, and can run `gcloud` commands.
