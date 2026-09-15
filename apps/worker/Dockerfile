FROM node:20-alpine AS base
RUN apk add --no-cache nodejs npm
RUN npm install -g pnpm@9.15.0

FROM base AS builder
WORKDIR /app
COPY . .
ENV COREPACK_PM_ON_FAIL=ignore
RUN pnpm install --frozen-lockfile --dangerously-allow-all-builds --pm-on-fail=ignore
RUN pnpm --filter @respondr/worker build
RUN pnpm --filter @respondr/worker deploy --prod --legacy /app/deploy

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/deploy/dist ./dist
COPY --from=builder /app/deploy/node_modules ./node_modules
EXPOSE 3001
CMD ["node", "dist/index.js"]