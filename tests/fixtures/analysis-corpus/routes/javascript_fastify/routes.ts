fastify.get('/fastify', handler)
fastify.route({ method: 'POST', url: '/fastify-object', handler })
fastify.route({ method: dynamicMethod, url: dynamicUrl, handler })
