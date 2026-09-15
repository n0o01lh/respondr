FROM node:20-alpine AS base
RUN npm install -g pnpm

FROM base AS builder
WORKDIR /app
COPY . .
RUN pnpm install --frozen-lockfile
RUN pnpm --filter @respondr/worker build
RUN pnpm --filter @respondr/worker deploy --prod --legacy /app/deploy

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/deploy/dist ./dist
COPY --from=builder /app/deploy/node_modules ./node_modules
EXPOSE 3001
CMD ["node", "dist/index.js"]