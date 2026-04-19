# =============================================================
# Stage 1 — Build
# =============================================================
FROM node:17-alpine AS builder

# Set the working directory 
WORKDIR /app

# Copy ONLY the dependency files 
COPY package*.json ./

# Install ALL dependencies
RUN npm ci 

# Copy the rest of the application code
COPY . .


# =============================================================
# Stage 2 — Runtime
# =============================================================
FROM node:17-alpine AS runtime

# Run as a non-root user for security.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only the installed node_modules from the builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy the application source code
COPY --from=builder /app .

# Switch to the non-root user
USER appuser

# Declare the port the app listens on.
EXPOSE 8080

# The command that starts the app.
CMD ["node", "server.js"]