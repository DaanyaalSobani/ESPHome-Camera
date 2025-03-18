# ESPHome Camera with HTTPS

This project sets up an ESPHome camera interface with HTTPS support using Nginx as a reverse proxy. It uses self-signed certificates for secure access both locally and over your LAN.

## Prerequisites

- Docker and Docker Compose
- OpenSSL
- Linux/Unix environment (for automatic LAN IP detection)
- Chrome/Chromium-based browser (for certificate management instructions)

## Setup Instructions

1. Clone the repository:
   ```bash
   git clone <your-repo-url>
   cd ESPHome-Camera
   ```

2. Generate SSL certificates:
   ```bash
   chmod +x generate_certs.sh
   ./generate_certs.sh
   ```
   This script will:
   - Create a Root CA certificate
   - Generate a server certificate signed by the Root CA
   - Automatically detect and include your LAN IP in the certificate
   - Set appropriate permissions for the certificate files

3. Import the Root CA certificate:

   ### Windows:
   1. Download the certificate from `https://<your-lan-ip>:6052/root-ca.crt`
   2. Double-click the downloaded `root-ca.crt` file
   3. Click "Install Certificate"
   4. Select "Local Machine" (requires admin rights)
   5. Click "Next"
   6. Select "Place all certificates in the following store"
   7. Click "Browse"
   8. Select "Trusted Root Certification Authorities"
   9. Click "OK", then "Next", then "Finish"
   10. Restart your browser

   ### Chrome/Linux:
   - Option 1: Download from the server
     - Start the containers (step 4)
     - Visit `https://<your-lan-ip>:6052/root-ca.crt`
     - Import the downloaded certificate
   - Option 2: Import directly from filesystem
     - Open Chrome and go to `chrome://settings/security`
     - Click on "Manage certificates"
     - Go to the "Authorities" tab
     - Click "Import"
     - Select the `certs/root-ca.crt` file (NOT certificate.crt)
   
   After importing:
   - Check all boxes when prompted and click "OK"
   - Restart your browser completely

4. Start the containers:
   ```bash
   docker compose up -d
   ```

## Accessing the Interface

After setup, you can access your ESPHome interface using either:
- Local: `https://localhost:6052`
- LAN: `https://<your-lan-ip>:6052`

## Security Notes

- The certificates are valid for 365 days
- The Root CA certificate is valid for 10 years
- Never share your `root-ca.key` or `private.key` files
- The certificates are self-signed and only trusted on devices where you've imported the Root CA

## Accessing from Other Devices

To access the interface from other devices on your network:
1. Download the root CA certificate by visiting `https://<your-lan-ip>:6052/root-ca.crt`
2. Import it into the device's certificate store
3. Access using `https://<your-lan-ip>:6052`

## File Structure

- `docker-compose.yaml`: Container configuration
- `nginx.conf`: Nginx reverse proxy configuration
- `generate_certs.sh`: Certificate generation script
- `certs/`: Directory containing SSL certificates (not in git)
- `config/`: ESPHome configuration directory

## Troubleshooting

1. Certificate Issues:
   - Make sure you've imported `root-ca.crt`, not `certificate.crt`
   - Ensure you've checked all trust boxes during import
   - Restart your browser completely after importing

2. Connection Issues:
   - Verify the containers are running: `docker compose ps`
   - Check container logs: `docker compose logs`
   - Ensure port 6052 is not blocked by your firewall

## Maintenance

- Regenerate certificates before they expire (365 days)
- Keep your Root CA certificate safe
- Regularly update your Docker images:
  ```bash
  docker compose pull
  docker compose up -d
  ``` 