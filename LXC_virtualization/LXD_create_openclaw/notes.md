




https://claude.ai/chat/128c4a25-e8a1-401a-b11b-5313ac0e6e02



https://openclaw.ai/

https://github.com/openclaw/openclaw  


### Homebrew install 

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"



==> Next steps:
- Run these commands in your terminal to add Homebrew to your PATH:
    echo >> /home/y/.bashrc
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> /home/y/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
- Install Homebrew's dependencies if you have sudo access:
    sudo apt-get install build-essential
  For more information, see:
    https://docs.brew.sh/Homebrew-on-Linux
- We recommend that you install GCC:
    brew install gcc
- Run brew help to get started
- Further documentation:
    https://docs.brew.sh




brew install gemini-cli









openclaw gateway restart

openclaw gateway status

openclaw doctor --generate-gateway-token

or

openclaw config get gateway.auth.token


cat ~/.openclaw/openclaw.json | grep -i token


671d02e864caae53b871b3e513cc11bfce2c6ca67d1f810e2f1d3210e8f22af3


72cc049fa8009541ebe478ed15e947baab4947d48979a5cb


ss -tlnp | grep 18789



http://10.69.215.153:18789/ 

http://127.0.0.1:18789/



enp5s0: 
    altname enx00163e3e58f3
    inet 10.69.215.153/24 metric 1024 brd 10.69.215.255 scope global dynamic enp5s0


ssh -N -L 18789:127.0.0.1:18789 openclow@10.69.215.153


lxc exec openclaw -- bash

cat /etc/ssh/sshd_config | grep -E "PermitRoot|PasswordAuth|ListenAddress|Port"



lxc exec openclaw -- bash -c "mkdir -p /root/.ssh && echo '$(cat ~/.ssh/id_rsa.pub)' >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"


systemctl restart ssh



ssh root@10.69.215.153

ssh openclaw@10.69.215.153





  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "allowedOrigins": [
        "http://localhost:18789",
        "http://127.0.0.1:18789"
      ],
      "allowInsecureAuth": true
    },
    "auth": {
      "mode": "token",
      "token": "671d02e864caae53b871b3e513cc11bfce2c6ca67d1f810e2f1d3210e8f22af3"
    },
    "tailscale": {
      "mode": "off",
      "resetOnExit": false






















