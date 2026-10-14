#!/bin/bash

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }

# 移除系统自带的 Python
apt remove python -y

# 安装依赖
apt-get install -y git
apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev git zip unzip

# 安装 Pyenv
curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash

# 配置环境变量
sed -i '/export PATH="\/root\/.pyenv\/bin:\$PATH"/d' ~/.bashrc
sed -i '/eval "\$(pyenv init -)"/d' ~/.bashrc
sed -i '/eval "\$(pyenv virtualenv-init -)"/d' ~/.bashrc

cat >> ~/.bashrc << EOF
export PATH="/root/.pyenv/bin:\$PATH"
eval "\$(pyenv init -)"
eval "\$(pyenv virtualenv-init -)"
EOF

# 更新环境变量
export PATH="/root/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# 安装 Python 3.14
pyenv install 3.14
pyenv global 3.14

# 下载并安装 ShadowsocksR
wget -c https://github.com/ProxyPanel/ShadowsocksR/archive/main.zip
unzip main.zip
wget ssrpanel.test/api/node/config -O ShadowsocksR-main/usermysql.json

pip install -r ShadowsocksR-main/requirements.txt
python3 ShadowsocksR-main/server.py
