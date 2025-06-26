FROM node:18-alpine as build

# Diretorio de trabalho dentro do container
WORKDIR /app

# Copiar arquivos de configuração do projeto
COPY package*.json ./

# Instalar dependancias
RUN npm install

COPY src/ ./src/
COPY tests/ ./tests/

# Executar testes
RUN npm run test

# Executar build da aplicação
RUN npm run build

FROM node:18-alpine

ENV NODE_ENV=production

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=build --chown=appuser:appgroup /app/package*.json ./
COPY --from=build --chown=appuser:appgroup /app/src ./src

RUN npm ci --only=production

EXPOSE 3000

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Comando para iniciar a aplicação
CMD ["node", "src/app.js"]
