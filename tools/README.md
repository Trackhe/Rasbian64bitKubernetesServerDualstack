# Tools for Deploy an Kubernetes Cluster.

## Install Ansible and AWX

**Required:**
Ubuntu Server 20.04 64bit.

1. Install Ansible:

```
sudo apt -y install ansible
```

2. Install Docker:

```
sudo apt install -y apt-transport-https gnupg-agent python3-pip && \
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```

```
sudo apt update && \
curl -fSLs https://get.docker.com | sudo sh
```

Give Docker User root:
```
sudo usermod -aG docker ubuntu
```

3. Install Docker Compose and Py

Note: if you have installed docker-py, please uninstall it with `sudo pip uninstall docker-py`

```
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

If you have telecom as your internet provider and the connection to github is slow so you can use `https://dl.trackhe.de/docker-compose-Linux-x86_64` as download Link.

// 19.12.2020 v1.27.4
```
sudo curl -L "https://dl.trackhe.de/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
```

```
sudo chmod +x /usr/local/bin/docker-compose
```

```
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose && \
sudo curl -L https://raw.githubusercontent.com/docker/compose/1.27.4/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
```

```
sudo pip install docker && \
sudo pip install docker-compose
```

4. Get root, clone AWX Repo and go into install dic.

```
sudo su
```

```
git clone --depth 50 https://github.com/ansible/awx.git && \
cd awx/installer/ && \
sed -i "s/admin_password=password/admin_password=admin/" inventory && \
sed -i "s/secret_key=awxsecret/secret_key=$(pwgen -N 1 -s 30)/" inventory
```
