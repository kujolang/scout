import Fastify from 'fastify'

const fastify = Fastify()
fastify.get('/health', async () => ({ ok: true }))
fastify.route({ method: 'POST', url: '/users', handler: createUser })
fastify.route({ url: '/users/:id', method: 'DELETE', handler: deleteUser })
fastify.route({ method: 'GET', path: '/status', handler: status })
fastify.route({ method: 'POST', url: dynamicPath, handler: unknownPath })

// A similarly named client is not a Fastify route.
client.route({ method: 'PUT', url: '/not-a-route' })
// fastify.route({ method: 'GET', url: '/comment-only' })
const guide = "fastify.route({ method: 'GET', url: '/string-only' })"
