<<<<<<< HEAD
# DevOps na Prática - Fase 2 (Melhorias Implementadas)

Este arquivo README documenta as melhorias implementadas no projeto DevOps na Prática para a Fase 2.

## Melhorias Implementadas

### 1. Expansão do Pipeline CI para CD

- **Arquivo**: `.github/workflows/ci-cd.yml`
- **Melhorias**:
  - Pipeline CI/CD completo com GitHub Actions
  - Etapas de segurança 
  - Build e push de imagem Docker para registry
  - Deploy automatizado para ambientes de staging e produção
  - Deploy canário para produção
  - Verificação de saúde pós-deploy
  - Rollback automatizado em caso de falha

### 2. Containerização com Docker

- **Arquivos**: `Dockerfile`, `docker-compose.yml`
- **Melhorias**:
  - Dockerfile multi-estágio para otimização
  - Usuário não-root para segurança
  - Healthcheck integrado
  - Docker Compose com orquestração de serviços
  - Stack de monitoramento (Prometheus, Grafana)

### 3. Scripts de Deploy Automatizado

- **Arquivos**: `deploy.sh`, `rollback.sh`
- **Melhorias**:
  - Deploy parametrizado por ambiente (dev/staging/prod)
  - Estratégia de deploy canário
  - Verificações de saúde pós-deploy
  - Rollback automatizado em caso de falha
  - Registro de versões anteriores para rollback

### 4. Aplicação Web Expandida

- **Arquivo**: `src/app.js`
- **Melhorias**:
  - Aplicação Express completa
  - Endpoint de health check
  - Exportação de métricas para Prometheus
  - Logging estruturado com Winston
  - Tratamento de erros não capturados

### 5. Testes Mais Abrangentes

- **Arquivos**: `tests/unit.test.js`, `tests/integration.test.js`
- **Melhorias**:
  - Testes unitários com Jest
  - Testes de integração com Supertest
  - Testes de performance básicos
  - Configuração de cobertura de código

### 6. Monitoramento e Observabilidade

- **Arquivos**: `monitoring/prometheus.yml`, `monitoring/grafana-provisioning/dashboards/app-dashboard.json`
- **Melhorias**:
  - Configuração do Prometheus
  - Dashboard Grafana para visualização de métricas
  - Métricas de requisições, erros e performance

## Como Executar o Projeto

### Requisitos

- Docker e Docker Compose
- Node.js 
- Git

### Passos para Execução Local

1. **Clone o repositório**:
   ```
   git clone https://github.com/PedroBarp/devops-na-pratica-fase_2.git
   cd devops-na-pratica-fase_2
   ```

2. **Instale as dependências**:
   ```
   npm install
   ```

3. **Execute os testes**:
   ```
   npm test
   ```

4. **Inicie a aplicação com Docker Compose**:
   ```
   docker-compose up -d
   ```

5. **Acesse a aplicação e monitoramento**:
   - Aplicação: http://localhost:{port}
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3001 (usuário: admin, senha: admin)

## Notas Adicionais

- Os scripts de deploy e rollback foram projetados para funcionar tanto localmente quanto e no pipeline 
- O dashboard Grafana inclui métricas de requisições, tempo de resposta, taxa de erros e uso de memória.

