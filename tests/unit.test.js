const app = require('../src/app');

// Mock das dependencias externas
jest.mock('winston', () => {
  return {
    format: {
      timestamp: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      combine: jest.fn().mockReturnThis(),
      colorize: jest.fn().mockReturnThis(),
      simple: jest.fn().mockReturnThis()
    },
    createLogger: jest.fn().mockReturnValue({
      info: jest.fn(),
      error: jest.fn()
    }),
    transports: {
      File: jest.fn(),
      Console: jest.fn()
    }
  };
});

jest.mock('prom-client', () => {
  return {
    Registry: jest.fn().mockReturnValue({
      registerMetric: jest.fn(),
      contentType: 'text/plain',
      metrics: jest.fn().mockResolvedValue('metrics data')
    }),
    collectDefaultMetrics: jest.fn(),
    Histogram: jest.fn().mockImplementation(() => ({
      labels: jest.fn().mockReturnValue({
        observe: jest.fn()
      })
    })),
    Counter: jest.fn().mockImplementation(() => ({
      labels: jest.fn().mockReturnValue({
        inc: jest.fn()
      })
    }))
  };
});

describe('Testes Unitários da Aplicação', () => {
  let mockResponse;
  
  beforeEach(() => {
    mockResponse = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn(),
      set: jest.fn(),
      end: jest.fn()
    };
  });
  
  // Teste da função de health check
  test('Health check deve retornar status 200 e objeto de saúde', () => {
    const mockRequest = {};
    
    // Encontrar a rota de health check no app
    const healthRoute = app._router.stack
      .filter(layer => layer.route)
      .find(layer => layer.route.path === '/health');
    
    const healthHandler = healthRoute.route.stack[0].handle;
    
    // Executar o handler diretamente
    healthHandler(mockRequest, mockResponse);
    
    expect(mockResponse.status).toHaveBeenCalledWith(200);
    expect(mockResponse.send).toHaveBeenCalled();
    
    // Verificar se o objeto enviado tem as propriedades esperadas
    const sentObject = mockResponse.send.mock.calls[0][0];
    expect(sentObject).toHaveProperty('uptime');
    expect(sentObject).toHaveProperty('message', 'OK');
    expect(sentObject).toHaveProperty('timestamp');
  });
  
  // Teste da rota de erro
  test('Rota de erro deve retornar status 500', () => {
    const mockRequest = {};
    
    // Encontrar a rota de erro no app
    const errorRoute = app._router.stack
      .filter(layer => layer.route)
      .find(layer => layer.route.path === '/error');
    
    const errorHandler = errorRoute.route.stack[0].handle;
    
    // Executar o hander diretamente
    errorHandler(mockRequest, mockResponse);
    
    expect(mockResponse.status).toHaveBeenCalledWith(500);
    expect(mockResponse.send).toHaveBeenCalledWith('Erro simulado para testes');
  });
  
  // Teste da rota de metricas
  test('Rota de métricas deve retornar dados do Prometheus', async () => {
    const mockRequest = {};
    
    // encontrar a rota de metricas no app
    const metricsRoute = app._router.stack
      .filter(layer => layer.route)
      .find(layer => layer.route.path === '/metrics');
    
    const metricsHandler = metricsRoute.route.stack[0].handle;
    
    // Executar o handler diretamente
    await metricsHandler(mockRequest, mockResponse);
    
    expect(mockResponse.set).toHaveBeenCalled();
    expect(mockResponse.end).toHaveBeenCalled();
  });
  
  // Teste do midleware de métricas
  test('Middleware de métricas deve registrar duração e contador', () => {
    const mockRequest = { method: 'GET', path: '/test' };
    const mockResponse = { 
      on: jest.fn().mockImplementation((event, callback) => {
        if (event === 'finish') {
          callback();
        }
      }),
      statusCode: 200
    };
    const nextFunction = jest.fn();
    
    // Encontrar o midleware de metricas
    const metricsMiddleware = app._router.stack
      .filter(layer => !layer.route)
      .find(layer => layer.name === '<anonymous>' && layer.handle.length === 3);
    
    // Executar o midleware
    metricsMiddleware.handle(mockRequest, mockResponse, nextFunction);
    
    expect(nextFunction).toHaveBeenCalled();
    expect(mockResponse.on).toHaveBeenCalledWith('finish', expect.any(Function));
  });
});

// Fizaliza o processo
afterAll(async () => {
      if (typeof app.close === 'function') {
        await app.close();
      }
});