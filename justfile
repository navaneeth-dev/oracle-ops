LB_IP := if _cluster_name == "dev" { `terraform -chdir=clusters/dev/infrastructure/ output -raw nlb_public_ip` } else { "140.245.250.113" }
CP1_IP := if _cluster_name == "dev" { `terraform -chdir=clusters/dev/infrastructure/ output -raw instance_public_ip` } else { "10.0.0.11" }
NODE_IP := "10.0.0.11"

KUBERNETES_VERSION := "1.35.0"
TALOS_VERSION := "1.12.0"
CLUSTER_NAME := if _cluster_name == "dev" { "rizexor-oracle-dev" } else { "controlplane-rizexor-prod1" }

# Extra flags for prod
_talosconfig_flag := if _cluster_name == "prod" { "--talosconfig talosconfig" } else { "" }

genconfig:
    sops -d secrets.sops.yaml > secrets.yaml
    talosctl gen config {{ CLUSTER_NAME }} https://{{ LB_IP }}:6443 \
      --with-secrets secrets.yaml \
      --kubernetes-version {{ KUBERNETES_VERSION }} --talos-version {{ TALOS_VERSION }} \
      --config-patch @patches/cert-approver.yaml --config-patch @patches/oracle-ntp.yaml \
      --config-patch @patches/hostdns.yaml --config-patch @patches/topolvm.yaml \
      --config-patch @patches/scheduling.yaml --config-patch @patches/cilium.yaml \
      --config-patch @multidoc/volume.yaml --config-patch-control-plane @patches/monitoring.yaml \
      --additional-sans {{ LB_IP }} --force
    talosctl config endpoint {{ LB_IP }} {{ _talosconfig_flag }}
    rm secrets.yaml

reboot:
    talosctl reboot -n {{ NODE_IP }}

applyconfig:
    talosctl apply-config -f controlplane.yaml -n {{ CP1_IP }} {{ if _cluster_name == "dev" { "-e " + CP1_IP + " -i" } else { "" } }}
    rm controlplane.yaml worker.yaml

bootstrap:
    talosctl bootstrap -n {{ LB_IP }} -e {{ LB_IP }}

kubeconfig:
    talosctl kubeconfig ./kubeconfig --nodes {{ NODE_IP }}

# For documentation purpose
cilium-install:
    helm template \
        cilium \
        cilium/cilium \
        --version 1.18.0 \
        --namespace kube-system \
        --set ipam.mode=kubernetes \
        --set kubeProxyReplacement=false \
        --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
        --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
        --set cgroup.autoMount.enabled=false \
        --set cgroup.hostRoot=/sys/fs/cgroup \
        --set envoy.enabled=false --set operator.replicas=1 > .cilium.yaml
