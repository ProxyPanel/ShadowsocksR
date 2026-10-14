#!/bin/bash

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }

# 安装依赖
apt-get install -y git make build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev zip unzip

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

# 下载安装 ShadowsocksR
rm -rf ShadowsocksR
git clone https://github.com/ProxyPanel/ShadowsocksR.git
cd ShadowsocksR || exit 1

pip install -r requirements.txt

# 由模板生成 userapiconfig.py / user-config.json / usermysql.json
bash initcfg.sh

echo
echo "下一步：编辑 usermysql.json（host/port/user/password/db/node_id）与 user-config.json，然后启动"
echo "  cd $PWD && sh logrun.sh"
