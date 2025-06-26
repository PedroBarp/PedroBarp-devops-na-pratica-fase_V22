const express = require('express');
const morgan = require('morgan');
const fs = require('fs');
const path = require('path');
const promClient = require('prom-client');
const winston = require('winston');

// Configuração do log

const logsDir = path.join(__dirname, 'logs');

if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

//const logDir = 'logs';
//if (!fs.existsSync(logDir)) {
//  fs.mkdirSync(logDir);
//}

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'devops-app' },
  transports: [
    new winston.transports.File({ filename: path.join(logDir, 'error.log'), level: 'error' }),
    new winston.transports.File({ filename: path.join(logDir, 'combined.log') }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// Metricas personalizadas
const httpRequestDurationMicroseconds = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duração das requisições HTTP em segundos',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestCounter = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total de requisições HTTP',
  labelNames: ['method', 'route', 'status_code']
});

register.registerMetric(httpRequestDurationMicroseconds);
register.registerMetric(httpRequestCounter);

const app = express();

// Midleware para logs de requisições
const accessLogStream = fs.createWriteStream(path.join(logDir, 'access.log'), { flags: 'a' });
app.use(morgan('combined', { stream: accessLogStream }));

// Midleware para métricas
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDurationMicroseconds
      .labels(req.method, route, res.statusCode)
      .observe(duration / 1000);
      
    httpRequestCounter
      .labels(req.method, route, res.statusCode)
      .inc();
  });
  
  next();
});

// Rota principal
app.get('/', (req, res) => {
  logger.info('Requisição recebida na rota principal');
  res.send('Hello DevOps World! Aplicação expandida com Express, monitoramento e logging.');
});

// Rota de health check
app.get('/health', (req, res) => {
  const healthcheck = {
    uptime: process.uptime(),
    message: 'OK',
    timestamp: Date.now()
  };
  
  try {
    // Aqui pode ser adicionadas verificações adicionais

    logger.info('Health check realizado com sucesso');
    res.status(200).send(healthcheck);
  } catch (error) {
    healthcheck.message = error;
    logger.error('Health check falhou', { error });
    res.status(500).send(healthcheck);
  }
});

// endpoint para metricas do prometheus
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    logger.error('Erro ao coletar métricas', { error });
    res.status(500).send('Erro ao coletar métricas');
  }
});

// Rota para simular erros
app.get('/error', (req, res) => {
  logger.error('Erro simulado para testes');
  res.status(500).send('Erro simulado para testes');
});

// Iniciar o servidor
const server = app.listen(0, () => {
  logger.info(`Servidor rodando em http://localhost:${server.address().port}`);
  console.log(`Servidor rodando em http://localhost:${server.address().port}`);
});

// Adiciona um metodo close ao app para fechar o servidor em testes
app.close = () => {
  return new Promise((resolve, reject) => {
    server.close((err) => {
      if (err) return reject(err);
      resolve();
    });
  });
};

// Tratamento de erros não capturados
process.on('uncaughtException', (error) => {
  logger.error('Erro não capturado', { error });
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Promessa rejeitada não tratada', { reason });
});

module.exports = app; 
