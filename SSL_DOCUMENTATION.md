# SSL Implementation for ESPHome-Camera

This document provides an in-depth explanation of the SSL/TLS implementation used in the ESPHome-Camera project, including why certain approaches were chosen, common issues that can arise, and how they were resolved.

## Why HTTPS?

HTTPS (HTTP Secure) provides several important benefits:

1. **Encryption**: All traffic between the client and server is encrypted, preventing eavesdropping.
2. **Authentication**: The server's identity is verified, preventing man-in-the-middle attacks.
3. **Data Integrity**: Ensures data hasn't been tampered with during transmission.

For IoT devices like ESPHome cameras, using HTTPS helps protect the privacy and security of your home network and device data.

## Our Implementation

### Self-Signed Certificates

This project uses self-signed certificates rather than certificates from a trusted Certificate Authority (CA) for several reasons:

- **Cost**: Trusted certificates cost money, which isn't necessary for internal use.
- **Internal Network**: Since this is running on a local network, a commercially trusted certificate isn't required.
- **Complete Control**: Self-signed certificates give you complete control over the certificate lifecycle.

### Certificate Architecture

Our SSL implementation uses three key files:

1. **Root CA Certificate** (`root-ca.crt`): A self-created Certificate Authority that acts as the trust anchor.
2. **Server Certificate** (`certificate.crt`): The certificate used by the nginx server, signed by our Root CA.
3. **Private Key** (`private.key`): The private key used by the server to authenticate itself.

### Nginx Configuration

The nginx server is configured to:
- Listen on port 6052 with SSL enabled (publicly exposed)
- Also configured for port 6053 internally (not exposed in docker-compose)
- Use modern TLS protocols (TLSv1.2 and TLSv1.3)
- Implement strong cipher suites
- Provide a download endpoint for the Root CA certificate
- Proxy requests to the ESPHome container

Key configuration points:
```nginx
server {
    listen 6052 ssl;
    
    # SSL configuration
    ssl_certificate /etc/nginx/certs/certificate.crt;
    ssl_certificate_key /etc/nginx/certs/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...;
    
    # Root CA certificate download endpoint
    location /root-ca.crt {
        alias /etc/nginx/certs/root-ca.crt;
        default_type application/x-x509-ca-cert;
        add_header Content-Disposition 'attachment; filename="root-ca.crt"';
    }
    
    # Proxy settings
    location / {
        proxy_pass http://esphome:6052;
        # Additional proxy settings...
    }
}
```

### Docker Configuration

The Docker Compose configuration exposes only port 6052 and mounts the certificates into the nginx container:

```yaml
services:
  nginx:
    # Other configuration...
    ports:
      - "6052:6052"
    volumes:
      - ./certs:/etc/nginx/certs
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
```

## Common SSL Issues and Solutions

### "Not Secure" Browser Warnings

**Cause**: Browsers don't trust self-signed certificates by default because they aren't signed by a known, trusted Certificate Authority.

**Solution**: Import the Root CA certificate into your browser or operating system's trusted certificate store. We implemented multiple ways to do this:

1. A dedicated download endpoint: `https://<your-ip>:6052/root-ca.crt`
2. Direct access to the certificate file in the `certs` directory

### Certificate Installation Problems

**Windows-specific issues**:
- Windows requires administrator privileges to install certificates
- The certificate must be installed in the "Trusted Root Certification Authorities" store
- You must choose "Local Machine" (not "Current User")
- Browsers need to be restarted after installation

**Chrome/Linux issues**:
- Chrome maintains its own certificate store
- Proper certificate store selection is crucial (check "Trust this certificate for identifying websites")

### Certificate Path Issues

**Cause**: When certificates aren't accessible to the nginx container, SSL handshakes fail.

**Solution**: We mounted the certificate directory as a volume in Docker:
```yaml
volumes:
  - ./certs:/etc/nginx/certs
```

### TLS Protocol and Cipher Issues

**Cause**: Some clients or servers may not support the same TLS protocols or cipher suites.

**Solution**: We configured nginx to use widely compatible but secure options:
- Modern TLS protocols (TLSv1.2 and TLSv1.3)
- Strong cipher suites that maintain compatibility with most clients

## Creating and Managing Certificates

### Certificate Generation Process

We use OpenSSL to generate our certificates with the following process:

1. Create a Root CA:
   ```bash
   openssl genrsa -out root-ca.key 2048
   openssl req -x509 -new -nodes -key root-ca.key -sha256 -days 3650 -out root-ca.crt
   ```

2. Create a server private key:
   ```bash
   openssl genrsa -out private.key 2048
   ```

3. Create a Certificate Signing Request (CSR):
   ```bash
   openssl req -new -key private.key -out server.csr
   ```

4. Sign the server certificate with the Root CA:
   ```bash
   openssl x509 -req -in server.csr -CA root-ca.crt -CAkey root-ca.key -CAcreateserial -out certificate.crt -days 365 -sha256
   ```

### Certificate Renewal

Self-signed certificates will eventually expire and need to be renewed. The process is:

1. Generate a new server certificate (steps 3-4 above)
2. Replace the old certificate files
3. Restart the nginx container to apply the changes

## WebSocket Issues and Troubleshooting

When implementing SSL with WebSockets, several challenges can arise that require specific configurations to address:

### Common WebSocket + SSL Issues

1. **WebSocket Handshake Failures**:
   - WebSocket requires a protocol upgrade from HTTP to WebSocket
   - When using SSL (WSS protocol), this handshake becomes more complex
   - Common error: `WebSocket connection to 'wss://hostname:port/path' failed`

2. **Connection Header Handling**:
   - The Connection header must be properly configured in nginx
   - Static value `"Upgrade"` can cause issues in some scenarios
   - Solution: Use a dynamic mapping based on the $http_upgrade variable:
     ```nginx
     map $http_upgrade $connection_upgrade {
         default upgrade;
         '' close;
     }
     ```

3. **Timeouts**:
   - WebSockets are long-lived connections and require extended timeouts
   - Default nginx timeouts are too short, causing dropped connections
   - Solution: Increase timeout values (read, send, connect) to 3600s or higher

4. **Proxy Configuration**:
   - All necessary headers must be properly forwarded to the backend
   - The complete set of headers includes: Upgrade, Connection, Host, X-Real-IP, etc.

### Direct HTTP Access for Testing

For troubleshooting purposes, we added direct access to the ESPHome container on port 6055, bypassing nginx and SSL encryption:

```yaml
esphome:
  # Other configuration...
  ports:
    - "6055:6052"  # Direct access to ESPHome without SSL
```

This allows you to:
1. Test if the issue is related to nginx or the SSL layer
2. Compare behavior between encrypted (wss://) and unencrypted (ws://) connections
3. Verify that the ESPHome container itself is functioning correctly

To use this direct access:
- Access ESPHome at `http://localhost:6055` 
- WebSocket connections will use `ws://` protocol instead of `wss://`

**Security Note**: This direct access should only be used for testing and debugging. For production use, the SSL-encrypted connection through nginx should be preferred for security reasons.

## Conclusion

Our SSL implementation provides a secure way to access the ESPHome interface while maintaining control over the certificate chain. By using a self-signed Root CA and providing easy access to this certificate, we ensure both security and usability.

The most common issues users face relate to certificate trust, which is why we've implemented multiple ways to obtain and install the Root CA certificate on different platforms. 