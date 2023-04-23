# インフラCI実践ガイドのDockerオンリーバージョン（Nested VM未使用）

この手順書は第1版本編のp65(3.5.3)-p66(3.5.4の途中) までの手順をNested VM未使用な環境で置き換えるものです。使用するGitLabやDockerのバージョンを2023年時点での比較的新しいものに置き換えています。その他の手順は本紙とほぼ同等です。

## 制限事項
- ホストOSとして CentOS 8 を想定しています。
- 最新版の Rootless Docker、および、Docker Compose V1 を必要とします。
- Windows, MacOS X の Docker では動きません（ホストOSとDockerデーモンの動作する場所の違い）
  - その場合は、VirtualBox等でCentOSを起動して、その中でDockerを動かしてください。
- 各演習章の最後に登場するクリーンアップで登場する `vagrant` を使った仮想OSの再構築は実行できませんので飛ばしてください。手順に沿った演習をしている限り問題にはなりません。

## 環境構築

以下の操作を全て `root` ではなく**一般ユーザ**で実施します。

Install Rootless Docker
```
$ sudo dnf clean all
$ sudo dnf repolist
$ sudo dnf install -y fuse-overlayfs iptables
$ curl -fsSL https://get.docker.com/rootless | sh
Some applications may require the following environment variable too:
export DOCKER_HOST=unix:///run/user/1000/docker.sock

$ echo 'export DOCKER_HOST=unix:///run/user/1000/docker.sock' >> ~/.bashrc
$ source .bashrc
$ echo $DOCKER_HOST
unix:///run/user/1000/docker.sock

$ systemctl --user start docker
$ systemctl --user enable docker
```

Configure Insecure Container Registry
```
$ mkdir -p ~/.config/docker/
$ echo '{"insecure-registries" : ["https://192.168.33.10:4567"]}' > ~/.config/docker/daemon.json
```

Install Docker Compose V1
```
$ echo alias docker-compose=\'docker run --rm -v /run/user/1000/docker.sock:/var/run/docker.sock:z -v \"\$PWD:/\$PWD:z\" -w \"/\$PWD\" docker/compose:1.29.2\' >> ~/.bashrc
$ source ~/.bashrc
```

Instal Ansible
```
$ sudo dnf install -y centos-release-ansible-29.noarch
$ sudo dnf install -y ansible
```

docker-compose.ymlをダウンロード
```
$ cd ~/
$ git clone https://github.com/kentarosasaki/ci-on-docker.git
$ cd ci-on-docker/docker/env_build/docker-compose/
```

`GITLAB_HOME` 環境変数の設定
> `.env` ファイルは、`docker-compose.yml`ファイルと同じディレクトリに設置する。
```
$ echo "GITLAB_HOME=$HOME/ci-on-docker/docker/env_build/docker-compose/" >> .env
```

パスワードやトークンを変更する場合は `volumes/gitlab.rb` の値を編集する。その後 compose を起動(3-5分かかります)

CI環境の起動
```
$ docker-compose up -d
```

5分ほど待って`curl`コマンドを実行する。応答があったら GitLab にログインできるようになる。
```
$ curl http://<演習用ホストサーバのIPアドレス>:8080
```

GitLabにログインする。
> `http://<演習用ホストサーバのIPアドレス>:8080` にアクセスしてログインする。ユーザーは `root` パスワードは `volumes/gitlab.rg` で設定した `initial_root_password` の値を使います。

gitlab-runner を GitLab に登録する。
> `RUNNER_TOKEN` には `volumes/gitlab.rg` で設定した値を使います。デフォルト値は、`token-AABBCCDD`です。

```
$ RUNNER_TOKEN=token-AABBCCDD
$ docker exec gitlab-runner \
  gitlab-runner register \
  --non-interactive \
  --url http://192.168.33.10 \
  --registration-token ${RUNNER_TOKEN:?} \
  --tag-list docker \
  --executor docker \
  --locked=false \
  --docker-image docker:latest \
  --clone-url http://192.168.33.10/ \
  --docker-volumes /run/user/1000/docker.sock:/var/run/docker.sock \
  --docker-privileged=true \
  --docker-network-mode gitlab_infraci_nw
```

成功時の出力例
```
Running in system-mode.

Registering runner... succeeded                     runner=token-AA
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
```

環境全体の設定作業（書籍版の環境と合わせるための作業）

- gitlab にログインする。ユーザーは `root` パスワードは `volumes/gitlab.rb` で設定した値。
- 新規プロジェクトを作成して import project -> repo by URL から `https://github.com/kentarosasaki/ci-on-docker.git` をインポートする。
- 作成されたプロジェクト `ci-on-docker` のプロジェクトページから CI/CD -> pipelines -> run pipeline からパインプラインを実行する。
- 全ての処理が成功すると本編と同じ環境に設定される。



## 演習の開始

演習を開始するには、以下のコマンドでコンソールサーバーへ接続してから行います（今回の手順ではCIホストにAnsible等が設定されず、代わりに console コンテナに設定が行われます）

```
docker exec -it -u vagrant console bash
```

P84 の `VAGRANT_PRIVATE_KEY` に設定する鍵の内容は紙面と同じ `cat ~/.ssh/infraci` で参照でいます。

## 本編との差分

本編ではホストマシンから vagrant ssh コマンドを利用してサーバーにログインする操作が含まれています。コンテナ環境を用いた場合は vagrant コマンドが利用できないため、代わりにホストマシンから docker exec コマンドか、コンソールから ssh コマンドを利用してください。


## Tips

本編のパイプラインは毎回コンテナのビルドが走るため、負荷が高く時間もかかります。.gitlab-ci.yml を`Unit_Package`を以下のように編集することで初回のみビルドが走るように変更できます。

```yaml
Unit_Package:
  stage: unit_prepare
  script:
    - |
        IMAGE_CHECK=`docker images -q ${CONTAINER_IMAGE_PATH}`
        if [ "${IMAGE_CHECK}" = "" ]; then
            docker login -u gitlab-ci-token -p ${CI_BUILD_TOKEN} ${CI_REGISTRY}
            docker build . -t ${CONTAINER_IMAGE_PATH}
            docker push ${CONTAINER_IMAGE_PATH}
        fi
  tags:
    - docker

```

## 環境の再起動等


CI演習ホスト上で以下を実行
```
$ cd ci-on-docker/docker/env_build/docker-compose/

# 停止
$ docker-compose stop

# 開始
$ docker-compose start

# 再起動
$ docker-compose restart

# 削除（やり直し)
$ docker-compose down

# 作成
$ docker-compose up -d
```

## インフラCIのデモとしてこの環境を使う場合

1. 上記の「環境構築」を実施する
2. GitLabへユーザーを追加する
   - 「user」を「Regular」権限で追加（その他はデフォルト）
3. プロジェクトの作成 → インポートを行う
   - インポート元: https://github.com/kentarosasaki/ketchup-vagrant-ansible.git
   - Visibility Level を 「Public」に設定
4. 「ketchup-vagrant-ansible 」プロジェクトに「user」を「developer」権限で追加する
5. プロジェクトのSettings -> CI/CD -> Secret Variables に変数を追加
   - 変数名に「VAGRANT_PRIVATE_KEY」を追加
   - 変数の内容は「~/.ssh/infraci」を設定する
     - 確認方法
     - `docker exec -it -u vagrant console bash`
     - `cat ~/.ssh/infraci`
6. 上記の「Tips」を実施し、2回目以降はビルドが走らないようにする
7. pipeline を一回動かしてみる

