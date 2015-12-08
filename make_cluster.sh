# Script to make a cluster for testing unit files stuck in a "No such
# file or directory" state.

# We make 5 nodes, all set up with etcd & fleet on CoreOS, but
# otherwise nothing special.

# Note: The environment variable SSH_SOURCE_CIDR should be set to a
# CIDR where you'd like to ssh from. In our case, this is the external
# address of our corporate firewall; obviously it'll be something
# different for other people.

set -eo pipefail

#set -x

token=$(curl -s https://discovery.etcd.io/new?size=3)

cat << EOF > cloud-config.txt
#cloud-config
coreos:
  etcd2:
    # generate a new token for each unique cluster from https://discovery.etcd.io/new
    discovery: $token
    # multi-region and multi-cloud deployments need to use \$public_ipv4
    advertise-client-urls: http://\$private_ipv4:2379
    initial-advertise-peer-urls: http://\$private_ipv4:2380
    listen-client-urls: http://0.0.0.0:2379,http://0.0.0.0:4001
    listen-peer-urls: http://\$private_ipv4:2380,http://\$private_ipv4:7001
  units:
    - name: etcd2.service
      command: start
    - name: fleet.service
      command: start
EOF

### Make the cluster on GCE
echo "#### Making a 5-node cluster on GCE: 3 etcd members, 2 etcd proxies..."
(
# Make a network
gcloud compute networks create trouble --range=10.240.0.0/16
# Make firewall rules
gcloud compute firewall-rules create trouble-internal --network=trouble --allow=icmp,tcp:1-65535,udp:1-65535 --source-ranges=10.240.0.0/16 &
gcloud compute firewall-rules create trouble-allow-ssh --network=trouble --allow=tcp:22 --source-ranges=$SSH_SOURCE_CIDR &

# Make 5 instances
gcloud compute instances create trouble-etcd-{a..e}                                        \
                                --zone=us-central1-a                                       \
                                --metadata-from-file=user-data=cloud-config.txt            \
                                --network=trouble                                          \
                                --image=coreos                                             \
                                --scopes=bigquery,datastore,sql,storage-rw,userinfo-email  \
                                --machine-type=n1-standard-1                               \
                                --maintenance-policy=MIGRATE &

wait
) > /dev/null
echo "#### Done"

# Wait a bit.
sleep 15

# Check etcd state on each host:
echo
echo "#### Now checking etcd health"
working=
failing=

for host in trouble-etcd-{a..e}; do
  echo -n "$host: "
  if gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="etcdctl ls" > /dev/null 2>&1; then
    echo OK
    working="$host $working"
  else
    echo FAILS
    failing="$host $failing"
  fi
done

if [ -n "$failing" ]; then
  echo
  echo "#### Grab a log"
  gcloud compute ssh $(echo $failing | cut -d ' ' -f 1) --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="sudo journalctl -u etcd2.service"
fi

echo
echo "#### Attempt to fix the failed hosts"
# Now fix the failing hosts.
for host in $failing; do
  gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="sudo rmdir /var/lib/etcd2/member"
done

# Give them a chance to start.
sleep 10

echo
echo "#### Check etcd health again"
# Now check the etcd state:
for host in trouble-etcd-{a..e}; do
  echo -n "$host: "
  if gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="etcdctl ls" > /dev/null 2>&1; then
    echo OK
  else
    echo FAILS
  fi
done


# But that's not the whole issue, because those "member" directories
# got recreated on the originally failed hosts:

echo
echo "#### Checking the content of /var/lib/etcd2"
for host in trouble-etcd-{a..e}; do
  echo "$host:"
  gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="ls -l /var/lib/etcd2"
done

echo
echo "#### Restart the etcd service on each of the hosts (rolling)"
for host in trouble-etcd-{a..e}; do
  echo "Restarting $host: "
  gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="sudo systemctl restart etcd2.service" || true
done
wait

# Pause to let the hosts settle down
sleep 15

echo
echo "#### Check etcd health again"
# Now check the etcd state:
for host in trouble-etcd-{a..e}; do
  echo -n "$host: "
  if gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="etcdctl ls" > /dev/null 2>&1; then
    echo OK
  else
    echo FAILS
  fi
done

# So here's the *real* workaround.
echo
echo "#### Fixing for real this time (by deleting the member directory while the proxy directory has valid proxy config)"
for host in $failing; do
  gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command='sudo rmdir /var/lib/etcd2/member'
done

sleep 10

echo
echo "#### Check etcd health again"
# Now check the etcd state:
for host in trouble-etcd-{a..e}; do
  echo -n "$host: "
  if gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="etcdctl ls" > /dev/null 2>&1; then
    echo OK
  else
    echo FAILS
  fi
done

echo
echo "#### Try the reset thing again"
for host in trouble-etcd-{a..e}; do
  echo "Restarting $host: "
  gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="sudo systemctl restart etcd2.service" || true
done
wait

# Pause to let the hosts settle down
sleep 10

echo
echo "#### Check etcd health again"
# Now check the etcd state:
for host in trouble-etcd-{a..e}; do
  echo -n "$host: "
  if gcloud compute ssh $host --ssh-flag=-q --ssh-flag=-A --zone=us-central1-a --command="etcdctl ls" > /dev/null 2>&1; then
    echo OK
  else
    echo FAILS
  fi
done

