# Запуск нагрузочных тестов Yandex Load Testing в GitHub Actions

В этом сценарии вы добавите этап запуска нагрузочных тестов [Yandex Load Testing](https://yandex.cloud/ru/docs/load-testing/) в ваш деплойный GitHub Actions CI Workflow.

Взаимодействие с Yandex Load Testing (запуск тестов, создание и удаление агентов нагрузочного тестирования) будет осуществляться с помощью экшенов, опубликованных в официальном аккаунте Yandex Cloud на GitHub: https://github.com/yandex-cloud/yc-github-loadtesting-ci.

> [!TIP]
> Примеры workflow:
> - [yandex-cloud/yc-github-loadtesting-ci: YC Load Testing example actions CI](https://github.com/yandex-cloud/yc-github-loadtesting-ci/actions/workflows/example.yml) - пример из репозитория с экшенами
> - [yandex/pandora: Performance tests](https://github.com/yandex/pandora/actions/workflows/perftest.yml) - перф-тесты генератора нагрузки Pandora

## 0. Подготовка

Ознакомьтесь с сервисом Yandex Load Testing; используя веб интерфейс консоли управления Yandex Cloud, проведите тесты, которые планируете запускать в CI.

1. Создайте (зарегистрируйте) агента, с которого будет проводиться нагрузочный тест  
   - [Создание агента в Compute Cloud](https://yandex.cloud/ru/docs/load-testing/operations/create-agent)
   - [Создание внешнего агента](https://yandex.cloud/ru/docs/load-testing/tutorials/loadtesting-external-agent)
1. Проведите нагрузочные тесты  
   - См. "Практические руководства" в [документации сервиса](https://yandex.cloud/ru/docs/load-testing/).
1. Сохраните файлы конфигураций тестов и тестовые данные

## 1. Настройка инфраструктуры

### 1.1. Создайте сервисный аккаунт, от имени которого будет осуществляться создание тестов и управление агентами

1. [Создайте сервисный аккаунт](https://yandex.cloud/ru/docs/iam/quickstart-sa) в используемом для нагрузочного тестирования каталоге
2. Назначте на созданный аккаунт необходимые роли:
   - Обязательные:
      - `loadtesting.loadTester`
   - Опциональные:  
      - Для создания и удаления агентов нагрузочного тестирования в Compute Cloud:
         - `iam.serviceAccounts.user`  
         - `compute.editor`  
         - `vpc.user`  
         - `vpc.publicAdmin`  
      - Для заливки файлов в Object Storage:
         - `storage.editor` (либо как клобальную роль в каталоге, либо в ACL конкретного бакета)
3. [Создайте авторизованный ключ](https://yandex.cloud/ru/docs/iam/concepts/authorization/key) для сервисного аккаунта, сохраните `json` файл с ключом локально на диск
4. Преобразуйте сохраненный файл ключа в base64, воспользовавшись стандартной утилитой командной строки:

   ```bash
   cat authorized_key.json | base64 > authorized_key.json.pem
   ```

> [!NOTE]
> Object Storage может использоваться как промежуточное хранилище необходимых для корректной работы теста файлов,
> к которым у агента изначально нет доступа:
> - хранящиеся в репозитории файлы с тестовыми данными
> - собираемые в рамках workflow исполняемые файлы генераторов)
> - ...

> [!WARNING]
> Для того, чтобы агент имел возможность скачать файлы из бакета Object Storage, его сервисному аккаунту должна быть выдана роль `storage.viewer`.

### 1.2. Определите необходимые секреты и переменные в настройках GitHub репозитория

В настройках вашего GitHub репозитория, перейдите в раздел **Secrets and variables** -\> **Actions** и добавьте**:

- Секреты:
  1. `YC_LOADTESTING_KEY_JSON_BASE64`: `******` - в качестве значения, вставьте содержимое закодированного в base64 файла авторизованного ключа (см. выше).
- Переменные:
  1. `YC_LOADTESTING_FOLDER_ID`: `aje*****************` - значение должно соответствовать идентификатору каталога, в котором будут создаваться тесты
  2. `YC_LOADTESTING_AGENT_SA_ID`: `b1g*****************` - значение должно соответствовать идентификатору сервисного аккаунта, используемого для авторизации исполняющего тесты агента

> [!TIP]
> Подробные инструкции:
> - [GitHub Security Guides: как добавить секрет](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository)
> - [GitHub Security Guides: как добавить переменную](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository)

## 2. Добавьте файлы конфигураций нагрузочных тестов в репозиторий

В произвольном месте репозитория, для каждого теста, создайте отдельную папку с именем, соответствущим имени теста. Добавьте в нее:

- файл конфигурации нагрузочного теста (имя файла должно соответствовать маске `test-config*.yaml`);
- (опционально) файлы с тестовыми данными;
- (опционально) файл `meta.json` с дополнительными параметрами теста (имя, описание, метки, файлы Object Storage, и т.д; см. инструкцию ниже);

> [!IMPORTANT]
> О структуре файлов и задании параметров теста: [README-howto-add-test.md](README-howto-add-test.md).

> [!TIP]
> Примеры: [sample-tests](sample-tests/).

## 3. Добавьте шаги нагрузочного тестирования в свой workflow

### 3.1. Запуск тестов

> [!NOTE]
> Спецификация экшена test-suite: [yandex-cloud/yc-github-loadtesting-ci/test-suite](https://github.com/yandex-cloud/yc-github-loadtesting-ci/tree/main?tab=readme-ov-file#action-test-suite).

1. Используя консоль управления, создайте (или подключите внешний) агент нагрузочного тестирования с именем `lt-manual-agent`
2. Убедитесь, что агент успешно подключился к сервису - статус должен быть `READY_FOR_TEST`
3. Добавьте шаг с запуском нагрузочного теста на этом агенте
   ```yaml
   name:
   on:
     - workflow_dispatch
   jobs:
     deploy-service:
       runs-on: ubuntu-latest
       steps:
         - run: 'echo "Here we deploy"'
   
     loadtesting-run-smoke:
       name: 'execute sample-tests/smoke'
       continue-on-error:true
       needs:
         - deploy-service
       runs-on: ubuntu-latest
       steps:
         # используем actions/checkout для того, чтобы получить доступ к файлам
         # в репозитории
         - uses: actions/checkout@v4
         # используем yandex-cloud/yc-github-loadtesting-ci/test-suite для запуска тестов
         - id: run
           # экшен для запуска
           uses: yandex-cloud/yc-github-loadtesting-ci/test-suite@main
           with:
             # значение секрета с авторизованным ключом
             auth-key-json-base64: ${{ secrets.YC_LOADTESTING_KEY_JSON_BASE64 }}
             # идентификатор каталога, в котором будет сохранятся информация
             # о запусках тестов.
             folder-id: ${{ vars.YC_LOADTESTING_FOLDER_ID }}
             # фильтр, по которому сервис будет определять, какой агент (один или несколько)
             # должен выполнять тест
             agent-filter: "name='lt-manual-agent'"
             # перечисление директорий с конфигурациями тестов.
             # одна директория - один запущенный тест
             test-directories: |-
               "${{ github.workspace }}/sample-tests/smoke
   ```
4. Запустите workflow

После первого запуска, результаты выполнения теста (и возможные ошибки) можно будет посмотреть на странице workflow.

### 3.2. (Опционально) Автоматическое создание и удаление агентов

> [!NOTE]
> Спецификация экшена agents-create: [yandex-cloud/yc-github-loadtesting-ci/agents-create](https://github.com/yandex-cloud/yc-github-loadtesting-ci/tree/main?tab=readme-ov-file#action-agents-create).

> [!NOTE]
> Спецификация экшена agents-delete: [yandex-cloud/yc-github-loadtesting-ci/agents-delete](https://github.com/yandex-cloud/yc-github-loadtesting-ci/tree/main?tab=readme-ov-file#action-agents-delete).

В целях экономии ресурсов и гарантированной изоляции среды выполнения тестов, можно модифицировать workflow так, чтобы агенты создавались и удалялись автоматически:

```yaml
name:
on:
  - workflow_dispatch
jobs:
  deploy-service:
    runs-on: ubuntu-latest
    steps:
      - run: 'echo "Here we deploy"'
      
  loadtesting-create-agent:
    name: 'create loadtesting compute agent'
    needs:
      - deploy-service
    runs-on: ubuntu-latest
    steps:
      - id: create-agents
        # используем yandex-cloud/yc-github-loadtesting-ci/agents-create для создания агентов
        uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
        with:
          # значение секрета с авторизованным ключом
          auth-key-json-base64: ${{ secrets.YC_LOADTESTING_KEY_JSON_BASE64 }}
          # идентификатор каталога, в котором агент будет создан
          folder-id: ${{ vars.YC_LOADTESTING_FOLDER_ID }}
          # количество создаваемых агентов
          count: 1
          # идентификатор сервисного аккаунта, который будет использоваться для авторизации
          # агентами в сервисе Load Testing
          service-account-id: ${{ vars.YC_LOADTESTING_AGENT_SA_ID }}
          # зона доступности, в которой будет развернута ВМ агента
          vm-zone: ru-central1-b
          # префикс имени создаваемого агента
          name-prefix: 'gh-actions-${{ github.run_id }}'

  loadtesting-run-smoke:
    name: 'execute sample-tests/smoke'
    continue-on-error:true
    needs:
      - loadtesting-create-agent
    runs-on: ubuntu-latest
    steps:
      # используем actions/checkout для того, чтобы получить доступ к файлам
      # в репозитории
      - uses: actions/checkout@v4
      # используем yandex-cloud/yc-github-loadtesting-ci/test-suite для запуска тестов
      - id: run
        # экшен для запуска
        uses: yandex-cloud/yc-github-loadtesting-ci/test-suite@main
        with:
          # значение секрета с авторизованным ключом
          auth-key-json-base64: ${{ secrets.YC_LOADTESTING_KEY_JSON_BASE64 }}
          # идентификатор каталога, в котором будет сохранятся информация
          # о запусках тестов.
          folder-id: ${{ vars.YC_LOADTESTING_FOLDER_ID }}
          # фильтр, по которому сервис будет определять, какой агент (один или несколько)
          # должен выполнять тест
          agent-filter: "name contains 'gh-actions-${{ github.run_id }}'"
          # перечисление директорий с конфигурациями тестов.
          # одна директория - один запущенный тест
          test-directories: |-
            "${{ github.workspace }}/sample-tests/smoke

  loadtesting-delete-agent:
    name: delete agents
    needs:
      - loadtesting-create-agent
      - loadtesting-run-smoke
    if: always()
    runs-on: ubuntu-latest
    steps:
      - id: delete-agents
        # используем yandex-cloud/yc-github-loadtesting-ci/agents-create для создания агентов
        uses: yandex-cloud/yc-github-loadtesting-ci/agents-delete@main
        with:
          # значение секрета с авторизованным ключом
          auth-key-json-base64: ${{ secrets.YC_LOADTESTING_KEY_JSON_BASE64 }}
          # идентификатор каталога c агентами, которые нужно удалить
          folder-id: ${{ vars.YC_LOADTESTING_FOLDER_ID }}
          # идентификаторы удаляемых агентов
          agent-ids: ${{ needs.loadtesting-create-agent.outputs.agent-ids }}
```

По сравнению с предыдущим шагом, в примере выше произошли следующие изменения:

- добавлен job `loadtesting-create-agent` для создания агента;
- в `loadtesting-run-smoke.steps.run.with.agent-filter` указан фильтр по имени, совпадающему с (уникальным) именем создаваемого агента;
- добавлен job `loadtesting-delete-agent` для автоматического удаления агента:
  - условие `if: always()` нужно для того, чтобы удаление агентов происходило даже в случае возникновения ошибки на предыдущих шагах;
  - `agent-ids: ${{ needs.loadtesting-create-agent.outputs.agent-ids }}` гарантирует, что удаляться будут только те агенты, которые были созданы на шаге `loadtesting-create-agent`;

## 4. (Дополнтительно) Настройте графики регрессий для запускаемых в CI тестов

Чтобы следить за эволюцией производительности сервиса/теста во времени, вы можете создать и настроить [графики регрессий](https://yandex.cloud/ru/docs/load-testing/concepts/load-test-regressions).
