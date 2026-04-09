dashboard:
    talosctl dashboard --nodes 10.0.0.11

applyconfig:
    talosctl apply-config -i -f controlplane.yaml \
      -n `terraform -chdir=../infrastructure/ output -raw instance_public_ip`
