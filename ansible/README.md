# Инфраструктурный код

## Структура

Используется набор Ansible плейбуков и ролей для установки и конфигурации разработанного решения.

### Роли

Используются роли :

* [*c136c2b*](https://github.com/geerlingguy/ansible-role-logstash/commit/c136c2bc7c567b30c8234f89e1a9ac1aa9b1589c) **[geerlinguy.logstash](https://github.com/geerlingguy/ansible-role-logstash)** *Модифицирован для работы с Nexus Proxy репозиторием*
* [*baa2e03*](https://github.com/geerlingguy/ansible-role-java/commit/baa2e03aabccb436e694bebb8ca13ed4ffaaf489) **[geerlinguy.java](https://github.com/geerlingguy/ansible-role-java)**

### Плейбуки

Плейбук **devopsevents.yml** устанавливает Python и зависимости для работы скриптов.
Для работы роли требуется **vault.key** в директории **/ansible** для расшифровки зашифрованных переменных.

## Пример использования

Для подключения с использованием комбинации Юзер/Пароль

```shell
ansible-playbook playbooks/devopsevents.yml  --extra-vars "ansible_user=<user> ansible_password=<user_pass> ansible_sudo_pass=<sudo_user_pass>" -i environments/<environment>/inventory.yml
```

## ToDo

* APT Nexus репозитрий Elastic
