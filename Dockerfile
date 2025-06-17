ARG INSTALLER=pnpm

FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
ARG INSTALLER

# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json pnpm-lock.yaml* package-lock.json* yarn.lock* ./
RUN \
  if [ "${INSTALLER}" == "pnpm" ]; then npm install -g pnpm && pnpm install --frozen-lockfile; \
  elif [ "${INSTALLER}" == "npm" ]; then npm ci; \
  elif [ "${INSTALLER}" == "yarn" ]; then yarn --frozen-lockfile; \
  else echo "Valid installer not set." && exit 1; \
  fi


# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# RUN chmod u+x ./installer && ./installer
ARG INSTALLER
RUN \
  if [ "${INSTALLER}" == "pnpm" ]; then pnpm run build; \
  elif [ "${INSTALLER}" == "npm" ]; then npm run build; \
  elif [ "${INSTALLER}" == "yarn" ]; then yarn build; \
  else echo "Valid installer not set." && exit 1; \
  fi

# Production image, copy all the files and run nginx
FROM nginx:alpine AS runner
COPY ./config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/dist /usr/share/nginx/html

WORKDIR /usr/share/nginx/html
