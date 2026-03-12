# ===== 构建阶段 =====
FROM node:22-alpine AS builder
WORKDIR /app

# ===== 构建参数 =====
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG NEXT_PUBLIC_WEB3FORMS_ACCESS_KEY
ARG NEXT_PUBLIC_GA_ID
ARG NEXT_PUBLIC_GITHUB_LATEST_RELEASE_URL

ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL \
    NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY \
    NEXT_PUBLIC_WEB3FORMS_ACCESS_KEY=$NEXT_PUBLIC_WEB3FORMS_ACCESS_KEY \
    NEXT_PUBLIC_GA_ID=$NEXT_PUBLIC_GA_ID \
    NEXT_PUBLIC_GITHUB_LATEST_RELEASE_URL=$NEXT_PUBLIC_GITHUB_LATEST_RELEASE_URL

# 安装依赖
COPY package*.json ./
RUN npm ci --legacy-peer-deps

# 复制源码并构建
COPY . .
RUN npm run build

# ===== 运行阶段 =====
FROM nginx:alpine AS runner
WORKDIR /usr/share/nginx/html

# 删除默认配置
RUN rm -rf ./* && \
    rm /etc/nginx/conf.d/default.conf && \
    sed -i '/listen.*80/d' /etc/nginx/nginx.conf

# 复制静态文件
COPY --from=builder /app/out .

# 复制 nginx 配置
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://0.0.0.0:3000 || exit 1
CMD ["nginx", "-g", "daemon off;"]

