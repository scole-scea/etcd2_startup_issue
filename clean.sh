#!/bin/bash

set -eo pipefail

gcloud compute instances delete trouble-etcd-{a..e} --zone=us-central1-a -q &
gcloud compute firewall-rules delete trouble-internal trouble-allow-ssh -q &
wait
gcloud compute networks delete trouble -q
