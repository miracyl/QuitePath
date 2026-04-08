FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN go build -o quite-path ./cmd/main/main.go
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/quite-path .
CMD ["./quite-path"]