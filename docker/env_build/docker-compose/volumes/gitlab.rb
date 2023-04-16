gitlab_rails['time_zone'] = 'Asia/Tokyo'
gitlab_rails['store_initial_root_password'] = true
gitlab_rails['display_initial_root_password'] = true
gitlab_rails['initial_root_password'] = '9@ae8TzRRyFbZ2ERKGrMeg*d'
gitlab_rails['initial_shared_runners_registration_token'] = 'token-AABBCCDD'
gitlab_rails['gitlab_shell_ssh_port'] = 2224
external_url 'http://192.168.33.10'
registry_external_url 'http://192.168.33.10:4567'
nginx['listen_port'] = 80
nginx['listen_https'] = false
letsencrypt['enable'] = false
