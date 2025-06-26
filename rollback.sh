
# Definição de variáveis
APP_NAME="devops-na-pratica-app"
CONTAINER_NAME="${APP_NAME}"
ENV=$1  

# Verificar se o ambiente foi especificado
if [ -z "$ENV" ]; then
  echo "Erro: Ambiente não especificado. Use: ./rollback.sh [dev|staging|prod]"
  exit 1
fi

if [ "$ENV" != "dev" ] && [ "$ENV" != "staging" ] && [ "$ENV" != "prod" ]; then
  echo "Erro: Ambiente inválido. Use: dev, staging ou prod"
  exit 1
fi

echo "Iniciando rollback para ambiente: $ENV"

# Verificar se existe uma versão anterior registrada
PREVIOUS_IMAGE_FILE="/tmp/${CONTAINER_NAME}-${ENV}-previous.txt"
if [ ! -f "$PREVIOUS_IMAGE_FILE" ]; then
  echo "Erro: Não foi encontrada uma versão anterior para rollback"
  exit 1
fi

# Ler a imagem anterior
PREVIOUS_IMAGE=$(cat $PREVIOUS_IMAGE_FILE)
if [ -z "$PREVIOUS_IMAGE" ]; then
  echo "Erro: Arquivo de versão anterior está vazio"
  exit 1
fi

echo "Realizando rollback para a versão anterior: $PREVIOUS_IMAGE"

if [ "$ENV" == "dev" ]; then
  PORT=3000
  VOLUME_MOUNT="-v $(pwd)/src:/app/src -v $(pwd)/logs:/app/logs"
  NETWORK_NAME="devops-network-dev"
elif [ "$ENV" == "staging" ]; then
  PORT=3001
  VOLUME_MOUNT="-v $(pwd)/logs:/app/logs"
  NETWORK_NAME="devops-network-staging"
else  # prod
  PORT=3000
  VOLUME_MOUNT="-v $(pwd)/logs:/app/logs"
  NETWORK_NAME="devops-network-prod"
fi

# Verificar se existe um container canario e remove-lo
CANARY_CONTAINER="${CONTAINER_NAME}-${ENV}-canary"
if docker ps -a | grep -q ${CANARY_CONTAINER}; then
  echo "Removendo container canário: ${CANARY_CONTAINER}"
  docker stop ${CANARY_CONTAINER}
  docker rm ${CANARY_CONTAINER}
fi

# parar e remover container atual
CONTAINER_NAME="${CONTAINER_NAME}-${ENV}"
if docker ps -a | grep -q ${CONTAINER_NAME}; then
  echo "Parando e removendo container atual: ${CONTAINER_NAME}"
  docker stop ${CONTAINER_NAME}
  docker rm ${CONTAINER_NAME}
fi

# Executar o container com a versão anterior
echo "Iniciando container com a versão anterior: ${CONTAINER_NAME} com a imagem ${PREVIOUS_IMAGE}"
docker run -d --name ${CONTAINER_NAME} \
  -p ${PORT}:3000 \
  --restart unless-stopped \
  --network $NETWORK_NAME \
  -e NODE_ENV=production \
  ${VOLUME_MOUNT} \
  ${PREVIOUS_IMAGE}

# Verificar se o container está em execução
if [ $? -ne 0 ]; then
  echo "Erro crítico: Falha ao iniciar o container com a versão anterior"
  echo "Sistema em estado inconsistente. Intervenção manual necessária."
  exit 2
fi

echo "Verificando status do container..."
sleep 5
if docker ps | grep -q ${CONTAINER_NAME}; then
  echo "Rollback concluído com sucesso! Container ${CONTAINER_NAME} está em execução com a versão anterior."
  
  echo "Verificando saúde da aplicação..."
  HEALTH_CHECK_URL="http://localhost:${PORT}/health"
  
  # Tentar até 5 vezes com intervalo de 5 segundos
  for i in {1..5}; do
    echo "Tentativa $i de 5..."
    HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_CHECK_URL)
    
    if [ "$HEALTH_STATUS" == "200" ]; then
      echo "✅ Aplicação está saudável após rollback!"
      break
    else
      echo "⚠️ Aplicação ainda não está respondendo corretamente (status: $HEALTH_STATUS)"
      
      if [ $i -eq 5 ]; then
        echo "❌ Falha na verificação de saúde após rollback. Intervenção manual necessária."
        exit 1
      fi
      
      echo "Aguardando 5 segundos antes da próxima tentativa..."
      sleep 5
    fi
  done
  
  # Exibir informações do ambiente
  echo "Aplicação disponível em:"
  if [ "$ENV" == "dev" ]; then
    echo "http://localhost:${PORT}"
  elif [ "$ENV" == "staging" ]; then
    echo "http://staging.example.com (ou http://localhost:${PORT} para testes locais)"
  else  
    echo "http://production.example.com (ou http://localhost:${PORT} para testes locais)"
  fi
  
  echo "Enviando notificação sobre o rollback..."
  
else
  echo "Erro crítico: Container não está em execução após o rollback"
  echo "Sistema em estado inconsistente. Intervenção manual necessária."
  exit 2
fi

# Exibir logs do container
echo "Exibindo logs do container após rollback (últimas 10 linhas):"
docker logs --tail 10 ${CONTAINER_NAME}

echo "Rollback para ambiente $ENV concluído com sucesso!"
exit 0
