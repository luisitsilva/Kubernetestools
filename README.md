# Kubernetestools
Tools to automate K8s environments!

Please match your OS name with the folder names available at this repo.
For every folder, a bash script is provided that will install: containerd as a CRI, weave-net as a CNI and the K8 tools (kubeadm, kubectl and kubelet).

Also to be noted on the scripts provided: it registers and uses the official pkgs.k8s.io, disabled swap on the fly and on boot.
If SELinux (RedHat based distros) or AppArmor (Ubuntu based distros) are configured, it disables the protection in order for the K8s cluster to operate.
