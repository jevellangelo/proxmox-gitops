FROM python:3.11-slim

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      curl openssh-client && \
    pip install --quiet ansible ansible-core ansible-lint hvac && \
    ansible-galaxy collection install ansible.posix community.hashi_vault && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
