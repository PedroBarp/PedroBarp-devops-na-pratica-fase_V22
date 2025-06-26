
# Definição de variaveis
APP_NAME="devops-na-pratica-app"
CONTAINER_NAME="${APP_NAME}"
ENV=$1  
DOCKER_IMAGE=$2  
CANARY_PERCENTAGE=0

shift 2
while [[ $# -gt 0 ]]; do
  case $1 in
    --canary)
      CANARY_PERCENTAGE=$2
      shift 2
      ;;
    --complete-canary)
      COMPLETE_CANARY=true
      shift
      ;;
    *)
      echo "Opção desconhecida: $1"
      exit 1
      ;;
  esac
done

# Verificar se o ambiente foi especificado
if [ -z "$ENV" ]; then
  echo "Erro: Ambiente não especificado. Use: ./deploy.sh [dev|staging|prod] [imagem_docker_opcional]"
  exit 1
fi

# Validar ambiente
if [ "$ENV" != "dev" ] && [ "$ENV" != "staging" ] && [ "$ENV" != "prod" ]; then
  echo "Erro: Ambiente inválido. Use: dev, staging ou prod"
  exit 1
fi

echo "Iniciando deploy para ambiente: $ENV"

# Registrar versão anterior para possível rollback
if docker ps -a | grep -q "${CONTAINER_NAME}-${ENV}"; then
  PREVIOUS_IMAGE=$(docker inspect --format='{{.Config.Image}}' ${CONTAINER_NAME}-${ENV})
  echo "Versão anterior registrada para possível rollback: $PREVIOUS_IMAGE"
  echo $PREVIOUS_IMAGE > /tmp/${CONTAINER_NAME}-${ENV}-previous.txt
fi

# Se a imagem Docker não foi especificada, construir localmente
if [ -z "$DOCKER_IMAGE" ]; then
  # Definir tag baseada no ambiente
  if [ "$ENV" == "prod" ]; then
    TAG="latest"
  else
    TAG="${ENV}-$(date +%Y%m%d%H%M%S)"
  fi
  
  DOCKER_IMAGE="${APP_NAME}:${TAG}"
  
  echo "Nenhuma imagem Docker especificada. Construindo localmente: ${DOCKER_IMAGE}"
  docker build -t ${DOCKER_IMAGE} .
  
  # Verifica se a construção foi bem-sucedida
  if [ $? -ne 0 ]; then
    echo "Erro: Falha ao construir a imagem Docker"
    exit 1
  fi
else
  echo "Usando imagem Docker fornecida: ${DOCKER_IMAGE}"
  
  # Verifica se a imagem existe localmente ou pode ser baixada
  docker pull ${DOCKER_IMAGE} || {
    echo "Erro: Não foi possível baixar a imagem ${DOCKER_IMAGE}"
    exit 1
  }
fi

# Configura variaveis especificas do ambiente
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

# Cria rede se não existir
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || docker network create $NETWORK_NAME

# Implementação de deploy canario para produção
if [ "$ENV" == "prod" ] && [ $CANARY_PERCENTAGE -gt 0 ]; then
  echo "Iniciando deploy canario com $CANARY_PERCENTAGE% do trafego"
  
  # Cria container canario
  CANARY_CONTAINER="${CONTAINER_NAME}-${ENV}-canary"
  
  # Para e remover container canario existente (se houver)
  if docker ps -a | grep -q ${CANARY_CONTAINER}; then
    echo "Parando e removendo container canario existente: ${CANARY_CONTAINER}"
    docker stop ${CANARY_CONTAINER}
    docker rm ${CANARY_CONTAINER}
  fi
  
  # Executa o container canario
  echo "Iniciando container canario: ${CANARY_CONTAINER} com a imagem ${DOCKER_IMAGE}"
  docker run -d --name ${CANARY_CONTAINER} \
    -p 3010:3000 \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    -e NODE_ENV=production \
    -e CANARY=true \
    ${VOLUME_MOUNT} \
    ${DOCKER_IMAGE}
  
  # Verifica se container canario esta em execução
  if ! docker ps | grep -q ${CANARY_CONTAINER}; then
    echo "Erro: Container canario não está em execução após o deploy"
    exit 1
  fi
  
  echo "Deploy canario concluído com sucesso Container ${CANARY_CONTAINER} está em execução."
  echo "Configurando balanceador de carga para direcionar $CANARY_PERCENTAGE% do tráfego para a versão canario"
  exit 0
fi

# Completa deploy canario 
if [ "$ENV" == "prod" ] && [ "$COMPLETE_CANARY" == "true" ]; then
  echo "Completando deploy canario - migrando 100% do tráfego para a nova versão"
  
  CANARY_CONTAINER="${CONTAINER_NAME}-${ENV}-canary"
  
  # Verifica se o container canario existe
  if ! docker ps | grep -q ${CANARY_CONTAINER}; then
    echo "Erro: Container canario não encontrado. Não é possível completar o deploy canario."
    exit 1
  fi
  
  # Obter a imagem do container canario
  CANARY_IMAGE=$(docker inspect --format='{{.Config.Image}}' ${CANARY_CONTAINER})
  
  # Para e remover container existente (se houver)
  CONTAINER_NAME="${CONTAINER_NAME}-${ENV}"
  if docker ps -a | grep -q ${CONTAINER_NAME}; then
    echo "Parando e removendo container existente: ${CONTAINER_NAME}"
    docker stop ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
  fi
  
  # Executa o novo container com a imagem canario
  echo "Iniciando novo container principal: ${CONTAINER_NAME} com a imagem ${CANARY_IMAGE}"
  docker run -d --name ${CONTAINER_NAME} \
    -p ${PORT}:3000 \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    -e NODE_ENV=production \
    ${VOLUME_MOUNT} \
    ${CANARY_IMAGE}
  
  # Verifica se o container está em execução
  if ! docker ps | grep -q ${CONTAINER_NAME}; then
    echo "Erro: Container principal não está em execução após completar o deploy canario"
    exit 1
  fi
  
  # Remove o container canario
  echo "Removendo container canario"
  docker stop ${CANARY_CONTAINER}
  docker rm ${CANARY_CONTAINER}
  
  echo "Deploy canario completado com sucesso! 100% do tráfego agora vai para a nova versão."
  exit 0
fi

# Deploy padrão 
# Para e remover container existente 
CONTAINER_NAME="${CONTAINER_NAME}-${ENV}"
if docker ps -a | grep -q ${CONTAINER_NAME}; then
  echo "Parando e removendo container existente: ${CONTAINER_NAME}"
  docker stop ${CONTAINER_NAME}
  docker rm ${CONTAINER_NAME}
fi

# Executa o novo container
echo "Iniciando novo container: ${CONTAINER_NAME} com a imagem ${DOCKER_IMAGE}"
docker run -d --name ${CONTAINER_NAME} \
  -p ${PORT}:3000 \
  --restart unless-stopped \
  --network $NETWORK_NAME \
  -e NODE_ENV=production \
  ${VOLUME_MOUNT} \
  ${DOCKER_IMAGE}

# Verifica se o container está em execução
if [ $? -ne 0 ]; then
  echo "Erro: Falha ao iniciar o container"
  exit 1
fi

echo "Verificando status do container..."
sleep 5
if docker ps | grep -q ${CONTAINER_NAME}; then
  echo "Deploy concluído com sucesso! Container ${CONTAINER_NAME} está em execução."
  
  # Verifica saúde da aplicação
  echo "Verificando saúde da aplicação..."
  HEALTH_CHECK_URL="http://localhost:${PORT}/health"
  
  # Tenta até 5 vezes com intervalo de 5 segundos
  for i in {1..5}; do
    echo "Tentativa $i de 5..."
    HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_CHECK_URL)
    
    if [ "$HEALTH_STATUS" == "200" ]; then
      echo "✅ Aplicação está saudável!"
      break
    else
      echo "⚠️ Aplicação ainda não está respondendo corretamente (status: $HEALTH_STATUS)"
      
      if [ $i -eq 5 ]; then
        echo "❌ Falha na verificação de saúde após 5 tentativas. Iniciando rollback..."
        ./rollback.sh $ENV
        exit 1
      fi
      
      echo "Aguardando 5 segundos antes da próxima tentativa..."
      sleep 5
    fi
  done
  
  echo "Aplicação disponível em:"
  if [ "$ENV" == "dev" ]; then
    echo "http://localhost:${PORT}"
  elif [ "$ENV" == "staging" ]; then
    echo "http://staging.example.com (ou http://localhost:${PORT} para testes locais)"
  else  
    echo "http://production.example.com (ou http://localhost:${PORT} para testes locais)"
  fi
else
  echo "Erro: Container não está em execução após o deploy"
  exit 1
fi


echo "Exibindo logs do container (últimas 10 linhas):"
docker logs --tail 10 ${CONTAINER_NAME}

echo "Deploy para ambiente $ENV concluído com sucesso!"
exit 0
