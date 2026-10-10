# ==============================================================================
# Build Stage: Compile and Package the Application
# ==============================================================================
FROM maven:3.9.9-eclipse-temurin-17 AS builder

WORKDIR /app

# Cache Maven dependencies by copying pom.xml first
COPY pom.xml .
RUN mvn dependency:go-offline -B || true

# Copy source code and package the Spring Boot executable JAR
COPY src ./src
RUN mvn clean package -DskipTests -B

# ==============================================================================
# Runtime Stage: Minimal JRE Container
# ==============================================================================
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

# Create a non-root system user and prepare upload directory
RUN groupadd -r spring && useradd -r -g spring spring && \
    mkdir -p /app/uploads/machinery && \
    chown -R spring:spring /app

# Copy the packaged Spring Boot fat JAR from builder stage
COPY --from=builder --chown=spring:spring /app/target/construction-management-*.jar app.jar

# Run as non-root user for container security
USER spring:spring

# Expose Render default port (Render injects PORT at runtime)
EXPOSE 8080

# Configure JVM memory limits optimized for Render instances (512MB RAM)
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -Djava.security.egd=file:/dev/./urandom"

# Healthcheck definition
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/api/health || exit 1

# Launch the Spring Boot application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
