FROM node:22-bookworm-slim
ENV NODE_ENV=production PORT=8080
WORKDIR /app
COPY --chown=node:node tools/analytics/serve.cjs tools/analytics/render-dashboard.cjs tools/analytics/dashboard-template.html tools/analytics/dashboard_queries.sql tools/analytics/cloud-bigquery.cjs tools/analytics/cloud-iap.cjs tools/analytics/cloud-run.cjs ./tools/analytics/
COPY --chown=node:node tools/analytics/output/synthetic-dashboard.json ./tools/analytics/output/
COPY --chown=node:node docs/analytics/trial_journey.sql ./docs/analytics/
USER node
EXPOSE 8080
CMD ["node","tools/analytics/cloud-run.cjs"]
