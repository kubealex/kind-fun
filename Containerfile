FROM quay.io/centos-bootc/centos-bootc:stream10
RUN dnf -y update && dnf -y install tmux mkpasswd
RUN pass=$(mkpasswd --method=SHA-512 --rounds=4096 redhat) && useradd -m -G wheel bootc-user -p $pass
RUN echo "%wheel        ALL=(ALL)       NOPASSWD: ALL" > /etc/sudoers.d/wheel-sudo
RUN echo -e "Welcome to the system!\nUnauthorized Access will be logged."  > /etc/motd.d/10-first-setup.motd
