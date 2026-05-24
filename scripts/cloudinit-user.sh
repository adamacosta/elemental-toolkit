#!/bin/sh

ROOT_DIR="$(dirname $(dirname $(realpath $0)))"

cat <<EOF | yq '.' | sed '/^$/d' > "$ROOT_DIR/tests/assets/user_setup.yaml"
stages:
  boot:
    - name: "Setup groups"
      ensure_entities:
        - entity: |
            kind: "group"
            group_name: "admin"
            password: "x"
            gid: 900
        - entity: |
            kind: "group"
            group_name: "elemental"
            password: "x"
            gid: 1000
    - name: "Setup users"
      users:
        elemental:
          name: "elemental"
          passwd: "$(openssl passwd -6 elemental)"
          groups:
            - "admin"
            - "systemd-journal"
          primary_group: "elemental"
          shell: /bin/bash
          ssh_authorized_keys:
$(awk '{print $1" "$2}' "$HOME/.ssh/id_ed25519.pub" | sed 's/^/            - /')
          homedir: "/home/elemental"
    - name: "Setup sudo"
      files:
        - path: "/etc/sudoers"
          owner: 0
          group: 0
          permissions: 0600
          content: |
            Defaults always_set_home
            Defaults secure_path="/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin:/usr/local/sbin"
            Defaults env_reset
            Defaults env_keep = "LANG LC_ADDRESS LC_CTYPE LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE LC_ATIME LC_ALL LANGUAGE LINGUAS XDG_SESSION_COOKIE"
            Defaults !insults
            root ALL=(ALL) ALL
            %admin ALL=(ALL) NOPASSWD: ALL
            @includedir /etc/sudoers.d
EOF