const request = require('supertest');
const app = require('../src/app');

describe('Testes de Integração da API', () => {
  // Teste da rota principal
  describe('GET /', () => {
    it('deve retornar status 200 e a mensagem correta', async () => {
      const response = await request(app).get('/');
      expect(response.statusCode).toBe(200);
      expect(response.text).toContain('Hello DevOps World');
    });
  });

  // Teste da rota de heath check
  describe('GET /health', () => {
    it('deve retornar status 200 e informações de saúde', async () => {
      const response = await request(app).get('/health');
      expect(response.statusCode).toBe(200);
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('message', 'OK');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  // Teste da rota de metricas
  describe('GET /metrics', () => {
    it('deve retornar status 200 e métricas do Prometheus', async () => {
      const response = await request(app).get('/metrics');
      expect(response.statusCode).toBe(200);
      expect(response.text).toContain('http_request_duration_seconds');
      expect(response.text).toContain('http_requests_total');
    });
  });

  // Teste da rota de erro
  describe('GET /error', () => {
    it('deve retornar status 500', async () => {
      const response = await request(app).get('/error');
      expect(response.statusCode).toBe(500);
    });
  });

  // Teste de rota inexistente
  describe('GET /rota-inexistente', () => {
    it('deve retornar status 404', async () => {
      const response = await request(app).get('/rota-inexistente');
      expect(response.statusCode).toBe(404);
    });
  });

  // Teste de performance basico
  describe('Performance da API', () => {
    it('deve responder em menos de 200ms', async () => {
      const start = Date.now();
      await request(app).get('/');
      const duration = Date.now() - start;
      expect(duration).toBeLessThan(200);
    });
  });
});



afterAll(async () => {
  await app.close();
});

